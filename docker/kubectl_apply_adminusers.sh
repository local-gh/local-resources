source ./kubectl_setup_args.sh

if [ -n "$ENV_FILE" ]; then
    echo "Skipping env setup"
else
    ENV_FILE="../.env"
    source ./kubectl_setup_env.sh
fi

if [ ! -d "./kubernetes/release/adminusers" ]; then
    mkdir -p "./kubernetes/release/adminusers"
    echo "Directory ./kubernetes/release/adminusers created."
else 
    echo "Directory ./kubernetes/release/adminusers already exists."
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f kubernetes/release/adminusers/dashboard-adminuser.yaml -n kubernetes-dashboard

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
for stack in "${STACK_ARRAY[@]}"; do
    adminusers_paths=$(find ./kubernetes/templates/adminusers -type f -name "${stack}-*")
    for path in $adminusers_paths; do
        filename=$(basename "$path")
        envsubst < kubernetes/release/adminusers/$filename | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - 
    done
done