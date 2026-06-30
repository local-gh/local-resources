kubectl_setup_nginx() {
    IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

    local NAMESPACE="default"
    local TIMEOUT=300
    local NGINX_POD_NAME
    NGINX_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^nginx.*Init" | awk '{print $1}' | head -n 1)

    if [[ -z "$NGINX_POD_NAME" ]]; then
        echo "No nginx pod found in init state"
        return 1
    fi

    echo "Copying files to nginx pod $NGINX_POD_NAME..."
    local start_time
    start_time=$(date +%s)
    while true; do
        local status status_key
        status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod "$NGINX_POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[*].state}')
        status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
        if [ "$status_key" = "running" ]; then
            echo "Pod $NGINX_POD_NAME init container is running"
            break
        fi

        local current_time elapsed_time
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
            echo "Timeout: Pod $NGINX_POD_NAME init did not start within $TIMEOUT seconds"
            return 1
        fi

        echo "Waiting for pod $NGINX_POD_NAME init container..."
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

    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/.htpasswd "$NGINX_POD_NAME:/tmp/etc/nginx/.htpasswd" -c init-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/ssl/root.crt "$NGINX_POD_NAME:/tmp/etc/ssl/root.crt" -c init-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/ssl/root.key "$NGINX_POD_NAME:/tmp/etc/ssl/root.key" -c init-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/ssl/root.pass "$NGINX_POD_NAME:/tmp/etc/ssl/root.pass" -c init-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/nginx/nginx.conf "$NGINX_POD_NAME:/tmp/etc/nginx/nginx.conf" -c init-nginx
    echo "Copied nginx config to $NGINX_POD_NAME"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kubectl_setup_nginx
fi
