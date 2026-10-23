kubectl_setup_nginx() {
    IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

    local NAMESPACE="default"
    # Recreate rollouts can take well over 5 minutes when the previous pod sits
    # on a NotReady node (NoExecute toleration is 300s) and the PVC then has to
    # be detached from the old droplet before init-nginx can start.
    local TIMEOUT="${NGINX_SETUP_TIMEOUT:-900}"
    local NGINX_POD_NAME=""
    local start_time
    start_time=$(date +%s)

    if [[ ! -s ./volumes/nginx/nginx.conf ]]; then
        echo "Missing ./volumes/nginx/nginx.conf — run setup_nginx.sh first"
        return 1
    fi
    if [[ ! -s ./volumes/nginx/.htpasswd ]]; then
        echo "Missing ./volumes/nginx/.htpasswd — run setup_password.sh / create htpasswd first"
        return 1
    fi

    echo "Waiting for an nginx pod in Init state..."
    local NGINX_RELOAD=""
    while true; do
        NGINX_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true 2>/dev/null \
            | grep "^nginx" | grep -i "Init" | awk '{print $1}' | head -n 1)

        local current_time elapsed_time
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        if [[ -n "$NGINX_POD_NAME" ]]; then
            local status status_key
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod "$NGINX_POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[*].state}' 2>/dev/null || true)
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $NGINX_POD_NAME init container is running"
                break
            fi
            echo "Pod $NGINX_POD_NAME found; init state=${status_key:-unknown}, waiting..."
        elif [ "$elapsed_time" -ge 30 ]; then
            # Re-deploys where the nginx deployment didn't change never produce
            # an Init pod — copy into the running pod and reload instead.
            NGINX_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true 2>/dev/null \
                | grep "^nginx" | grep "Running" | grep -v -i "terminating" | awk '{print $1}' | head -n 1)
            if [[ -n "$NGINX_POD_NAME" ]]; then
                echo "No Init pod; updating config in running pod $NGINX_POD_NAME"
                NGINX_RELOAD=1
                break
            fi
            echo "No nginx Init pod yet..."
        else
            echo "No nginx Init pod yet..."
        fi

        if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
            echo "Timeout: no nginx init container ready within $TIMEOUT seconds"
            return 1
        fi
        sleep 5
    done

    # init-nginx stages at /tmp/etc/nginx; the running container serves the
    # same volume at /etc/nginx (shared subPath mount).
    local target_container="init-nginx"
    local target_root="/tmp/etc/nginx"
    if [[ -n "$NGINX_RELOAD" ]]; then
        target_container="nginx"
        target_root="/etc/nginx"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/core.conf "$NGINX_POD_NAME:$target_root/conf.d/http/core.conf" -c "$target_container"
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/stream/core.conf "$NGINX_POD_NAME:$target_root/conf.d/stream/core.conf" -c "$target_container"
    else
        echo "Skipping nginx core config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "ecommerce" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/ecommerce.conf "$NGINX_POD_NAME:$target_root/conf.d/http/ecommerce.conf" -c "$target_container"
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/stream/ecommerce.conf "$NGINX_POD_NAME:$target_root/conf.d/stream/ecommerce.conf" -c "$target_container"
    else
        echo "Skipping nginx ecommerce config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "ai" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/ai.conf "$NGINX_POD_NAME:$target_root/conf.d/http/ai.conf" -c "$target_container"
    else
        echo "Skipping nginx ai config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "blog" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/blog.conf "$NGINX_POD_NAME:$target_root/conf.d/http/blog.conf" -c "$target_container"
    else
        echo "Skipping nginx blog config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "s3" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/s3.conf "$NGINX_POD_NAME:$target_root/conf.d/http/s3.conf" -c "$target_container"
    else
        echo "Skipping nginx s3 config"
    fi

    # Copy nginx.conf last — init exits as soon as this file is non-empty.
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/.htpasswd "$NGINX_POD_NAME:$target_root/.htpasswd" -c "$target_container"
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/nginx.conf "$NGINX_POD_NAME:$target_root/nginx.conf" -c "$target_container"
    echo "Copied nginx config to $NGINX_POD_NAME"

    if [[ -n "$NGINX_RELOAD" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" exec "$NGINX_POD_NAME" -c nginx -- nginx -s reload
        echo "Reloaded nginx in $NGINX_POD_NAME"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kubectl_setup_nginx
fi
