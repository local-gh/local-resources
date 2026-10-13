if [ -n "$ENV_FILE" ]; then
    echo "Skipping kong env setup"
else
    ENV_FILE=".env"
    source ./load_env.sh
fi

template="./volumes/api/kong.yml.template"
output="./volumes/api/kong.yml"

if [[ ! -f "$template" ]]; then
    echo "Missing Kong template at $template"
    exit 1
fi

export SUPABASE_ANON_KEY="${ANON_KEY:?ANON_KEY is required for Kong}"
export SUPABASE_SERVICE_KEY="${SERVICE_ROLE_KEY:?SERVICE_ROLE_KEY is required for Kong}"
export DASHBOARD_USERNAME="${DASHBOARD_USERNAME:?DASHBOARD_USERNAME is required for Kong}"
export DASHBOARD_PASSWORD="${DASHBOARD_PASSWORD:?DASHBOARD_PASSWORD is required for Kong}"

# Realtime resolves the self-hosted tenant from the upstream Host header.
# Compose uses container_name realtime-dev.supabase-realtime; K8s Service is realtime-dev.
if [ -z "${KONG_REALTIME_HOST:-}" ]; then
    if [ -n "${KUBECONFIG_PATH:-}" ] || [ -n "${KUBECONFIG_FILE:-}" ]; then
        export KONG_REALTIME_HOST="realtime-dev"
    else
        export KONG_REALTIME_HOST="realtime-dev.supabase-realtime"
    fi
fi
echo "Kong realtime upstream host=${KONG_REALTIME_HOST}"

envsubst '${SUPABASE_ANON_KEY} ${SUPABASE_SERVICE_KEY} ${DASHBOARD_USERNAME} ${DASHBOARD_PASSWORD} ${KONG_REALTIME_HOST}' \
    < "$template" > "${output}.tmp"

if [[ "${CORE_ANALYTICS_REPLICAS:-0}" -eq 0 ]]; then
    sed '/^  ## Analytics routes$/,/^  ## Secure Database routes$/{
        /^  ## Secure Database routes$/!d
    }' "${output}.tmp" > "$output"
    echo "Removed Kong analytics routes (CORE_ANALYTICS_REPLICAS=0)"
else
    mv "${output}.tmp" "$output"
fi

rm -f "${output}.tmp"
echo "Generated $output"
