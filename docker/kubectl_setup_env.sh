ENV_FILE="${ENV_FILE:-.env}"
if [ ! -f "$ENV_FILE" ] && [ -f "../.env" ]; then
    ENV_FILE="../.env"
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

source ./load_env.sh

TMP_ENV=$(mktemp)
trap 'rm -f "$TMP_ENV"' EXIT

# Compose-style ${POSTGRES_*} placeholders in database URLs are not expanded by --from-env-file.
envsubst '${POSTGRES_PASSWORD} ${POSTGRES_HOST} ${POSTGRES_PORT} ${POSTGRES_DB}' \
    < "$ENV_FILE" > "$TMP_ENV"

kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret env-secrets --ignore-not-found
kubectl --kubeconfig="$KUBECONFIG_PATH" create secret generic env-secrets --from-env-file="$TMP_ENV"
echo "Created env-secrets from $ENV_FILE (database URLs expanded)"
