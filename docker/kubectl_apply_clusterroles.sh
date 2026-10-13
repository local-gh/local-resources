source ./kubectl_setup_args.sh

if [ -n "$ENV_FILE" ]; then
    echo "Skipping env cluster roles setup"
else
    ENV_FILE=".env"
    source ./kubectl_setup_env.sh
fi

if [ ! -d "./kubernetes/release/clusterroles" ]; then
    mkdir -p "./kubernetes/release/clusterroles"
    echo "Directory ./kubernetes/release/clusterroles created."
else 
    echo "Directory ./kubernetes/release/clusterroles already exists."
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f kubernetes/release/clusterroles/dashboard-clusterrole.yaml -n kubernetes-dashboard

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
for stack in "${STACK_ARRAY[@]}"; do
    clusterroles_paths=$(find ./kubernetes/templates/clusterroles -type f -name "${stack}-*")
    for path in $clusterroles_paths; do
        filename=$(basename "$path")
        envsubst < kubernetes/release/clusterroles/$filename | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - 
    done
done