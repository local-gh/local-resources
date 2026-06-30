source ./kubectl_setup_args.sh

if [ -n "$ENV_FILE" ]; then
    echo "Using ENV_FILE=$ENV_FILE for env-secrets"
else
    ENV_FILE=".env"
fi
source ./kubectl_setup_env.sh

if [ ! -d "./kubernetes/release/secrets" ]; then
    mkdir -p "./kubernetes/release/secrets"
    echo "Directory ./kubernetes/release/secrets created."
else 
    echo "Directory ./kubernetes/release/secrets already exists."
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f kubernetes/release/dashboard-secret.yaml -n kubernetes-dashboard

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
for stack in "${STACK_ARRAY[@]}"; do
    secrets_paths=$(find ./kubernetes/templates/secrets -type f -name "${stack}-*")
    for path in $secrets_paths; do
        filename=$(basename "$path")
        envsubst < kubernetes/release/secrets/$filename | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - 
    done
done