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

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

NGINX_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^nginx" | awk '{print $1}' | head -n 1)
kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $NGINX_DEPLOYMENT_NAME

if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
    ANALYTICS_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^analytics" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $ANALYTICS_DEPLOYMENT_NAME -n default
    AUTH_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^auth" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $AUTH_DEPLOYMENT_NAME -n default
    DB_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^db" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $DB_DEPLOYMENT_NAME -n default
    IMGPROXY_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^imgproxy" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $IMGPROXY_DEPLOYMENT_NAME -n default
    KONG_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^kong" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $KONG_DEPLOYMENT_NAME -n default
    META_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^meta" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $META_DEPLOYMENT_NAME -n default
    REALTIME_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^realtime" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $REALTIME_DEPLOYMENT_NAME -n default
    REST_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^rest" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $REST_DEPLOYMENT_NAME -n default
    STORAGE_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^storage" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $STORAGE_DEPLOYMENT_NAME -n default
    STUDIO_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^studio" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $STUDIO_DEPLOYMENT_NAME -n default
    SUPAVISOR_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^supavisor" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $SUPAVISOR_DEPLOYMENT_NAME -n default
    VECTOR_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^vector" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $VECTOR_DEPLOYMENT_NAME -n default
else
    echo "Skipping core stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "ecommerce" ]]; then
    MEDUSA_SERVER_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^medusa-server" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $MEDUSA_SERVER_DEPLOYMENT_NAME -n default
    MEILISEARCH_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^meilisearch" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $MEILISEARCH_DEPLOYMENT_NAME -n default
    REDIS_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^redis" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $REDIS_DEPLOYMENT_NAME -n default
else
    echo "Skipping core stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "blog" ]]; then
    GHOST_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^ghost" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $GHOST_DEPLOYMENT_NAME -n default
    GHOST_DB_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^ghost-db" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $GHOST_DB_DEPLOYMENT_NAME -n default
else
    echo "Skipping blog stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "s3" ]]; then
    MINIO_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^minio" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $MINIO_DEPLOYMENT_NAME -n default
else
    echo "Skipping core stack"
fi

if [[ "${STACK_ARRAY[@]}" =~ "ai" ]]; then
    ETCD_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^etcd" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $ETCD_DEPLOYMENT_NAME -n default
    OLLAMA_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^ollama" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $OLLAMA_DEPLOYMENT_NAME -n default
    OPEN_WEBUI_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^open-webui" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $OPEN_WEBUI_DEPLOYMENT_NAME -n default
    OPENEDAI_SPEECH_SERVER_DEPLOYMENT_NAME=$(kubectl get deployments --no-headers=true | grep "^openedai-speech-server" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $OPENEDAI_SPEECH_SERVER_DEPLOYMENT_NAME -n default
    STANDALONE_DEPLOYMENT_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get deployments --no-headers=true | grep "^standalone" | awk '{print $1}' | head -n 1)
    kubectl --kubeconfig="$KUBECONFIG_PATH" rollout restart deployment $STANDALONE_DEPLOYMENT_NAME -n default
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