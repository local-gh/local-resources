NGINX_DEPLOYMENT_NAME="nginx-deployment"
NGINX_CONF_DIR="./volumes/nginx"

# Publishes the generated nginx config (setup_nginx.sh / setup_password.sh output)
# as ConfigMaps + a Secret that nginx-deployment.yaml mounts directly. Nothing is
# copied into a running pod, so nginx recovers on its own after any reschedule.
kubectl_apply_nginx_config() {
    if [[ ! -s "$NGINX_CONF_DIR/nginx.conf" ]]; then
        echo "Missing $NGINX_CONF_DIR/nginx.conf — run setup_nginx.sh first"
        return 1
    fi
    if [[ ! -s "$NGINX_CONF_DIR/.htpasswd" ]]; then
        echo "Missing $NGINX_CONF_DIR/.htpasswd — run setup_password.sh / create htpasswd first"
        return 1
    fi

    local kc=(kubectl --kubeconfig="$KUBECONFIG_PATH")
    local http_args=() stream_args=() f

    for f in "$NGINX_CONF_DIR"/conf.d/http/*.conf; do
        [[ -e "$f" ]] && http_args+=(--from-file="$f")
    done
    for f in "$NGINX_CONF_DIR"/conf.d/stream/*.conf; do
        [[ -e "$f" ]] && stream_args+=(--from-file="$f")
    done

    "${kc[@]}" create configmap nginx-conf \
        --from-file=nginx.conf="$NGINX_CONF_DIR/nginx.conf" \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
    "${kc[@]}" create configmap nginx-conf-http "${http_args[@]}" \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
    "${kc[@]}" create configmap nginx-conf-stream "${stream_args[@]}" \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
    "${kc[@]}" create secret generic nginx-htpasswd \
        --from-file=.htpasswd="$NGINX_CONF_DIR/.htpasswd" \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1

    NGINX_CONFIG_HASH=$(cat "$NGINX_CONF_DIR/nginx.conf" "$NGINX_CONF_DIR/.htpasswd" \
        "$NGINX_CONF_DIR"/conf.d/http/*.conf "$NGINX_CONF_DIR"/conf.d/stream/*.conf 2>/dev/null \
        | sha256sum | cut -c1-16)
    export NGINX_CONFIG_HASH
    echo "Applied nginx config (checksum ${NGINX_CONFIG_HASH}): ${#http_args[@]} http conf, ${#stream_args[@]} stream conf"
}

# Applies the config, rolls the deployment if the config changed, and waits for
# the rollout. Returns non-zero (with pod diagnostics) if nginx does not come up.
kubectl_setup_nginx() {
    local NAMESPACE="default"
    local TIMEOUT="${NGINX_SETUP_TIMEOUT:-900}"
    local kc=(kubectl --kubeconfig="$KUBECONFIG_PATH" -n "$NAMESPACE")

    kubectl_apply_nginx_config || return 1

    if ! "${kc[@]}" get deployment "$NGINX_DEPLOYMENT_NAME" >/dev/null 2>&1; then
        echo "Deployment $NGINX_DEPLOYMENT_NAME not found (NGINX_REPLICAS=0?); config applied only"
        return 0
    fi

    # No-op when the checksum already matches (fresh apply bakes it in via envsubst).
    "${kc[@]}" patch deployment "$NGINX_DEPLOYMENT_NAME" --type merge \
        -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"checksum/nginx-config\":\"${NGINX_CONFIG_HASH}\"}}}}}" >/dev/null || return 1

    echo "Waiting for $NGINX_DEPLOYMENT_NAME rollout (timeout ${TIMEOUT}s)..."
    if "${kc[@]}" rollout status deployment "$NGINX_DEPLOYMENT_NAME" --timeout="${TIMEOUT}s"; then
        return 0
    fi

    echo "nginx rollout did not complete; current pods:"
    "${kc[@]}" get pods -l service=nginx-core -o wide || true
    local pod
    pod=$("${kc[@]}" get pods -l service=nginx-core --no-headers -o custom-columns=:metadata.name 2>/dev/null | head -n 1)
    if [[ -n "$pod" ]]; then
        "${kc[@]}" logs "$pod" -c nginx --tail=50 || true
    fi
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source ./kubectl_setup_args.sh
    kubectl_setup_nginx
fi
