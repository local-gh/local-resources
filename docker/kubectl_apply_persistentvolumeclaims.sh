source ./kubectl_setup_args.sh

if [ -n "$ENV_FILE" ]; then
    echo "Skipping env persistentvolumeclaims setup"
else
    ENV_FILE=".env"
    source ./kubectl_setup_env.sh
fi

if [ ! -d "./kubernetes/release/persistentvolumeclaims" ]; then
    mkdir -p "./kubernetes/release/persistentvolumeclaims"
    echo "Directory ./kubernetes/release/persistentvolumeclaims created."
else 
    echo "Directory ./kubernetes/release/persistentvolumeclaims already exists."
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f kubernetes/release/persistentvolumeclaims/nginx-ssl-persistentvolumeclaim.yaml

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
for stack in "${STACK_ARRAY[@]}"; do
    persistentvolumeclaims_paths=$(find ./kubernetes/templates/persistentvolumeclaims -type f -name "${stack}-*")
    for path in $persistentvolumeclaims_paths; do
        filename=$(basename "$path")
        envsubst < kubernetes/release/persistentvolumeclaims/$filename | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - 
    done
done