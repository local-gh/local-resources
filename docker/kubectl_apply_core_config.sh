# Publishes the generated core config (setup_kong.sh / setup_ssl.sh output and
# volumes/db/*.sql) as Secrets/ConfigMaps that the kong and db deployments
# mount directly. Nothing is copied into a running pod, so both recover on
# their own after any reschedule.
kubectl_apply_core_config() {
    IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
    if [[ ! "${STACK_ARRAY[@]}" =~ "core" ]]; then
        echo "Skipping core config (core stack not enabled)"
        return 0
    fi

    local kc=(kubectl --kubeconfig="$KUBECONFIG_PATH")
    local f
    for f in ./volumes/ssl/root.crt ./volumes/ssl/root.key \
             ./volumes/db/realtime.sql ./volumes/db/webhooks.sql ./volumes/db/roles.sql \
             ./volumes/db/jwt.sql ./volumes/db/_supabase.sql ./volumes/db/logs.sql; do
        if [[ ! -s "$f" ]]; then
            echo "Missing $f — run setup_ssl.sh / check volumes/db"
            return 1
        fi
    done

    "${kc[@]}" create secret generic db-ssl \
        --from-file=server.crt=./volumes/ssl/root.crt \
        --from-file=server.key=./volumes/ssl/root.key \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
    "${kc[@]}" create configmap db-init-scripts \
        --from-file=98-webhooks.sql=./volumes/db/webhooks.sql \
        --from-file=99-roles.sql=./volumes/db/roles.sql \
        --from-file=99-jwt.sql=./volumes/db/jwt.sql \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
    "${kc[@]}" create configmap db-migrations \
        --from-file=97-_supabase.sql=./volumes/db/_supabase.sql \
        --from-file=99-realtime.sql=./volumes/db/realtime.sql \
        --from-file=99-logs.sql=./volumes/db/logs.sql \
        --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
    echo "Applied db config (db-ssl, db-init-scripts, db-migrations)"

    if [[ "${CORE_KONG_REPLICAS:-0}" -gt 0 ]]; then
        if [[ ! -s ./volumes/api/kong.yml ]]; then
            echo "Missing ./volumes/api/kong.yml — run setup_kong.sh first"
            return 1
        fi
        # kong.yml embeds ANON_KEY / SERVICE_ROLE_KEY / dashboard credentials.
        "${kc[@]}" create secret generic kong-config \
            --from-file=kong.yml=./volumes/api/kong.yml \
            --dry-run=client -o yaml | "${kc[@]}" apply -f - || return 1
        KONG_CONFIG_HASH=$(sha256sum ./volumes/api/kong.yml | cut -c1-16)
        echo "Applied kong config (checksum ${KONG_CONFIG_HASH})"
    else
        KONG_CONFIG_HASH="disabled"
    fi
    export KONG_CONFIG_HASH
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source ./kubectl_setup_args.sh
    kubectl_apply_core_config
fi
