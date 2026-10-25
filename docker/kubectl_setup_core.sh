IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
    # db and kong mount their config from ConfigMaps/Secrets published by
    # kubectl_apply_core_config.sh; only vector/analytics still need a copy.
    NAMESPACE="default"
    TIMEOUT=300

    VECTOR_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^vector.*Init" | awk '{print $1}' | head -n 1)
    if [[ "${CORE_VECTOR_REPLICAS:-0}" -eq 0 ]]; then
        echo "Skipping vector setup (CORE_VECTOR_REPLICAS=0)"
    elif [[ -z "$VECTOR_POD_NAME" ]]; then
        echo "No pod found with label service=vector"
    else
        start_time=$(date +%s)
        while true; do
            # Check if the pod is running
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod $VECTOR_POD_NAME -n $NAMESPACE -o jsonpath='{.status.initContainerStatuses[*].state}')
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $VECTOR_POD_NAME is running"
                break
            else
                current_time=$(date +%s)
                elapsed_time=$((current_time - start_time))
                
                if [ $elapsed_time -ge $TIMEOUT ]; then
                    echo "Timeout: Pod $VECTOR_POD_NAME did not run within $TIMEOUT seconds"
                    break
                fi
                
                echo "Waiting for pod $VECTOR_POD_NAME to be running..."
                sleep 5 # Wait for 5 seconds before checking again
            fi
        done
    
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/logs/vector.yml $VECTOR_POD_NAME:/tmp/etc/vector/vector.yml -c init-vector
    fi

    ANALYTICS_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^analytics.*Init" | awk '{print $1}' | head -n 1)
    if [[ "${CORE_ANALYTICS_REPLICAS:-0}" -eq 0 ]]; then
        echo "Skipping analytics setup (CORE_ANALYTICS_REPLICAS=0)"
    elif [[ -z "$ANALYTICS_POD_NAME" ]]; then
        echo "No pod found with label service=analytics"
    else
        start_time=$(date +%s)
        while true; do
            # Check if the pod is running
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod $ANALYTICS_POD_NAME -n $NAMESPACE -o jsonpath='{.status.initContainerStatuses[*].state}')
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $ANALYTICS_POD_NAME is running"
                break
            else
                current_time=$(date +%s)
                elapsed_time=$((current_time - start_time))
                
                if [ $elapsed_time -ge $TIMEOUT ]; then
                    echo "Timeout: Pod $ANALYTICS_POD_NAME did not run within $TIMEOUT seconds"
                    break
                fi
                
                echo "Waiting for pod $ANALYTICS_POD_NAME to be running..."
                sleep 5 # Wait for 5 seconds before checking again
            fi
        done
    
        kubectl --kubeconfig="$KUBECONFIG_PATH" exec -it $ANALYTICS_POD_NAME -- sh -c "echo '127.0.0.1 $NGINX_LOGFLARE_HOST_URL' >> /etc/hosts"
    fi
else
    echo "Skipping core stack"
fi