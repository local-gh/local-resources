kubectl_setup_kong() {
    IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

    if [[ ! "${STACK_ARRAY[@]}" =~ "core" ]]; then
        echo "Skipping Kong setup (core stack not enabled)"
        return 0
    fi

    if [[ "${CORE_KONG_REPLICAS:-0}" -eq 0 ]]; then
        echo "Skipping Kong setup (CORE_KONG_REPLICAS=0)"
        return 0
    fi

    if [[ ! -f ./volumes/api/kong.yml ]]; then
        echo "Missing ./volumes/api/kong.yml — run setup_kong.sh first"
        return 1
    fi

    local NAMESPACE="default"
    local TIMEOUT=300
    local KONG_POD_NAME
    KONG_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^kong.*Init" | awk '{print $1}' | head -n 1)
    if [[ -z "$KONG_POD_NAME" ]]; then
        echo "No Kong pod found in init state"
        return 1
    fi

    local start_time
    start_time=$(date +%s)
    while true; do
        local status status_key
        status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod "$KONG_POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[*].state}')
        status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
        if [ "$status_key" = "running" ]; then
            echo "Pod $KONG_POD_NAME init container is running"
            break
        fi

        local current_time elapsed_time
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
            echo "Timeout: Pod $KONG_POD_NAME init did not start within $TIMEOUT seconds"
            return 1
        fi

        echo "Waiting for pod $KONG_POD_NAME init container..."
        sleep 5
    done

    kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/api/kong.yml "$KONG_POD_NAME:/tmp/home/kong/kong.yml" -c init-kong
    echo "Copied kong.yml to $KONG_POD_NAME"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    kubectl_setup_kong
fi
