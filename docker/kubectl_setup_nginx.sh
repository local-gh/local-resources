kubectl_setup_nginx() {
    IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

    local NAMESPACE="default"
    local TIMEOUT=300
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
    while true; do
        NGINX_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true 2>/dev/null \
            | grep "^nginx" | grep -i "Init" | awk '{print $1}' | head -n 1)

        if [[ -n "$NGINX_POD_NAME" ]]; then
            local status status_key
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod "$NGINX_POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[*].state}' 2>/dev/null || true)
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $NGINX_POD_NAME init container is running"
                break
            fi
            echo "Pod $NGINX_POD_NAME found; init state=${status_key:-unknown}, waiting..."
        else
            echo "No nginx Init pod yet..."
        fi

        local current_time elapsed_time
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
            echo "Timeout: no nginx init container ready within $TIMEOUT seconds"
            return 1
        fi
        sleep 5
    done

    if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/core.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/http/core.conf" -c init-nginx
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/stream/core.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/stream/core.conf" -c init-nginx
    else
        echo "Skipping nginx core config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "ecommerce" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/ecommerce.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/http/ecommerce.conf" -c init-nginx
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/stream/ecommerce.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/stream/ecommerce.conf" -c init-nginx
    else
        echo "Skipping nginx ecommerce config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "ai" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/ai.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/http/ai.conf" -c init-nginx
    else
        echo "Skipping nginx ai config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "blog" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/blog.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/http/blog.conf" -c init-nginx
    else
        echo "Skipping nginx blog config"
    fi

    if [[ "${STACK_ARRAY[@]}" =~ "s3" ]]; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/conf.d/http/s3.conf "$NGINX_POD_NAME:/tmp/etc/nginx/conf.d/http/s3.conf" -c init-nginx
    else
        echo "Skipping nginx s3 config"
    fi

    # Copy nginx.conf last — init exits as soon as this file is non-empty.
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/.htpasswd "$NGINX_POD_NAME:/tmp/etc/nginx/.htpasswd" -c init-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/nginx.conf "$NGINX_POD_NAME:/tmp/etc/nginx/nginx.conf" -c init-nginx
    echo "Copied nginx config to $NGINX_POD_NAME"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kubectl_setup_nginx
fi
