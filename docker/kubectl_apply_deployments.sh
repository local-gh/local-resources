source ./kubectl_setup_args.sh
source ./kubectl_replicas_helpers.sh

if [ -n "$ENV_FILE" ]; then
    echo "Skipping env deployments setup"
else
    ENV_FILE=".env"
    source ./kubectl_setup_env.sh
fi

if [ ! -d "./kubernetes/release/deployments" ]; then
    mkdir -p "./kubernetes/release/deployments"
    echo "Directory ./kubernetes/release/deployments created."
else 
    echo "Directory ./kubernetes/release/deployments already exists."
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f kubernetes/release/deployments/nginx-deployment.yaml

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
for stack in "${STACK_ARRAY[@]}"; do
    deployments_paths=$(find ./kubernetes/templates/deployments -type f -name "${stack}-*")
    for path in $deployments_paths; do
        filename=$(basename "$path")
        if [[ -f kubernetes/release/deployments/$filename ]]; then
            envsubst < kubernetes/release/deployments/$filename | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f -
        else
            resource_name="$(manifest_resource_name "$path")"
            kubectl --kubeconfig="$KUBECONFIG_PATH" delete deployment "$resource_name" --ignore-not-found
            echo "Removed deployment $resource_name (replicas=0)"
        fi
    done
done