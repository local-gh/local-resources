source ./kubectl_setup_args.sh

ENV_FILE="${ENV_FILE:-.env}"
if [ ! -f "$ENV_FILE" ] && [ -f "../.env" ]; then
    ENV_FILE="../.env"
fi
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found"
    exit 1
fi
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
        ''|\#*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    export "$key=$value"
done < "$ENV_FILE"

source ./kubectl_replicas_helpers.sh

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

source ./setup_kong.sh

NGINX_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^nginx" | awk '{print $1}' | head -n 1)
kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $NGINX_DEPLOYMENT_NAME

if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
    restart_deployment_if_replicas "${CORE_ANALYTICS_REPLICAS:-0}" "analytics" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_AUTH_REPLICAS:-0}" "auth" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_DB_REPLICAS:-0}" "db" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_IMGPROXY_REPLICAS:-0}" "imgproxy" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_KONG_REPLICAS:-0}" "kong" "$KUBECONFIG_PATH"
    if [[ "${CORE_KONG_REPLICAS:-0}" -gt 0 ]]; then
        source ./kubectl_setup_kong.sh
        kubectl_setup_kong
    fi
    restart_deployment_if_replicas "${CORE_META_REPLICAS:-0}" "meta" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_REALTIME_REPLICAS:-0}" "realtime" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_REST_REPLICAS:-0}" "rest" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_STORAGE_REPLICAS:-0}" "storage" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_STUDIO_REPLICAS:-0}" "studio" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_SUPAVISOR_REPLICAS:-0}" "supavisor" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${CORE_VECTOR_REPLICAS:-0}" "vector" "$KUBECONFIG_PATH"
else
    echo "Skipping core stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "ecommerce" ]]; then
    restart_deployment_if_replicas "${ECOMMERCE_MEDUSA_SERVER_REPLICAS:-0}" "medusa-server" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${ECOMMERCE_MEILISEARCH_REPLICAS:-0}" "meilisearch" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${ECOMMERCE_REDIS_REPLICAS:-0}" "redis" "$KUBECONFIG_PATH"
else
    echo "Skipping ecommerce stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "blog" ]]; then
    restart_deployment_if_replicas "${BLOG_GHOST_REPLICAS:-0}" "ghost" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${BLOG_DB_REPLICAS:-0}" "ghost-db" "$KUBECONFIG_PATH"
else
    echo "Skipping blog stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "s3" ]]; then
    restart_deployment_if_replicas "${S3_MINIO_REPLICAS:-0}" "minio" "$KUBECONFIG_PATH"
else
    echo "Skipping s3 stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "ai" ]]; then
    restart_deployment_if_replicas "${AI_ETCD_REPLICAS:-0}" "etcd" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${AI_OLLAMA_REPLICAS:-0}" "ollama" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${AI_OPEN_WEBUI_REPLICAS:-0}" "open-webui" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${AI_OPENEDAI_SPEECH_SERVER_REPLICAS:-0}" "openedai-speech-server" "$KUBECONFIG_PATH"
    restart_deployment_if_replicas "${AI_STANDALONE_REPLICAS:-0}" "standalone" "$KUBECONFIG_PATH"
else
    echo "Skipping ai stack"
fi

DASHBOARD_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^dashboard" | awk '{print $1}' | head -n 1)
kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $DASHBOARD_DEPLOYMENT_NAME -n kubernetes-dashboard

if [ -z "${SKIP_DASHBOARD_PROXY:-}" ] && [ -z "${CI:-}" ]; then
    kubectl --kubeconfig="$KUBECONFIG_PATH" proxy &

    echo 'Dashboard token:'
    kubectl --kubeconfig="$KUBECONFIG_PATH" get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
fi

exit 0