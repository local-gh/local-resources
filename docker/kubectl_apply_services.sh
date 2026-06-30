source ./kubectl_setup_args.sh
source ./kubectl_replicas_helpers.sh

if [ -n "$ENV_FILE" ]; then
    echo "Skipping env services setup"
else
    ENV_FILE=".env"
    source ./kubectl_setup_env.sh
fi

if [ ! -d "./kubernetes/release/services" ]; then
    mkdir -p "./kubernetes/release/services"
    echo "Directory ./kubernetes/release/services created."
else 
    echo "Directory ./kubernetes/release/services already exists."
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f kubernetes/release/services/nginx-service.yaml

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
for stack in "${STACK_ARRAY[@]}"; do
    services_paths=$(find ./kubernetes/templates/services -type f -name "${stack}-*")
    for path in $services_paths; do
        filename=$(basename "$path")
        if [[ -f kubernetes/release/services/$filename ]]; then
            envsubst < kubernetes/release/services/$filename | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f -
        else
            resource_name="$(manifest_resource_name "$path")"
            kubectl --kubeconfig="$KUBECONFIG_PATH" delete service "$resource_name" --ignore-not-found
            echo "Removed service $resource_name (replicas=0)"
        fi
    done
done