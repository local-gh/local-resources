ENV_FILE="${ENV_FILE:-.env}"
if [ ! -f "$ENV_FILE" ] && [ -f "../.env" ]; then
    ENV_FILE="../.env"
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT

# Load .env and write a quote-stripped copy for kubectl --from-env-file.
# kubectl does not strip dotenv quotes, so PGRST_DB_SCHEMAS="public,..." would become
# schema "public (with a literal quote) and PostgREST returns 503.
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
    printf '%s=%s\n' "$key" "$value" >> "$TMP_ENV"
done < "$ENV_FILE"

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required in $ENV_FILE}"
POSTGRES_HOST="${POSTGRES_HOST:-db}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

urlencode() {
    local str="$1"
    local length="${#str}"
    local i c
    for (( i = 0; i < length; i++ )); do
        c="${str:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}

ENCODED_POSTGRES_PASSWORD="$(urlencode "$POSTGRES_PASSWORD")"

export GOTRUE_DB_DATABASE_URL="postgres://supabase_auth_admin:${ENCODED_POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
export PGRST_DB_URI="postgres://authenticator:${ENCODED_POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
export STORAGE_DATABASE_URL="postgres://supabase_storage_admin:${ENCODED_POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
export ANALYTICS_POSTGRES_BACKEND_URL="postgresql://supabase_admin:${ENCODED_POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/_supabase"
export MEDUSA_DATABASE_URL="postgres://supabase_admin:${ENCODED_POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

DATABASE_URL_KEYS=(
    GOTRUE_DB_DATABASE_URL
    PGRST_DB_URI
    STORAGE_DATABASE_URL
    ANALYTICS_POSTGRES_BACKEND_URL
    MEDUSA_DATABASE_URL
)

for key in "${DATABASE_URL_KEYS[@]}"; do
    grep -v "^${key}=" "$TMP_ENV" > "${TMP_ENV}.next" || true
    mv "${TMP_ENV}.next" "$TMP_ENV"
done

{
    printf 'GOTRUE_DB_DATABASE_URL=%s\n' "$GOTRUE_DB_DATABASE_URL"
    printf 'PGRST_DB_URI=%s\n' "$PGRST_DB_URI"
    printf 'STORAGE_DATABASE_URL=%s\n' "$STORAGE_DATABASE_URL"
    printf 'ANALYTICS_POSTGRES_BACKEND_URL=%s\n' "$ANALYTICS_POSTGRES_BACKEND_URL"
    printf 'MEDUSA_DATABASE_URL=%s\n' "$MEDUSA_DATABASE_URL"
} >> "$TMP_ENV"

if ! grep -q '^GOTRUE_DB_DATABASE_URL=postgres://' "$TMP_ENV"; then
    echo "Error: failed to build GOTRUE_DB_DATABASE_URL"
    exit 1
fi

: "${KUBECONFIG_PATH:?KUBECONFIG_PATH is required (e.g. bash kubectl_apply_secrets.sh -c /path/to/kubeconfig)}"

echo "Using PGRST_DB_SCHEMAS=${PGRST_DB_SCHEMAS-}"
if [[ "${PGRST_DB_SCHEMAS-}" == \"* ]] || [[ "${PGRST_DB_SCHEMAS-}" == \'* ]]; then
    echo "Error: PGRST_DB_SCHEMAS still has surrounding quotes after parse: ${PGRST_DB_SCHEMAS}"
    exit 1
fi

kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret env-secrets --ignore-not-found
kubectl --kubeconfig="$KUBECONFIG_PATH" create secret generic env-secrets --from-env-file="$TMP_ENV"
echo "Created env-secrets from $ENV_FILE"
echo "GOTRUE_DB_DATABASE_URL host=${POSTGRES_HOST} port=${POSTGRES_PORT} db=${POSTGRES_DB}"

# Show what landed in the cluster (no secrets beyond schemas list).
kubectl --kubeconfig="$KUBECONFIG_PATH" get secret env-secrets \
    -o jsonpath='{.data.PGRST_DB_SCHEMAS}' | base64 -d
echo
