IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

if [[ "${STACK_ARRAY[@]}" =~ "core" ]]; then
    # Copy files to the pod
    echo "Copying files to core..."
    NAMESPACE="default"
    TIMEOUT=300
    DB_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^db.*Init" | awk '{print $1}' | head -n 1)
    if [[ -z "$DB_POD_NAME" ]]; then
        echo "No pod found with label service=db"
    else
        start_time=$(date +%s)
        while true; do
            # Check if the pod is running
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod $DB_POD_NAME -n $NAMESPACE -o jsonpath='{.status.initContainerStatuses[*].state}')
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $DB_POD_NAME is running"
                break
            else
                current_time=$(date +%s)
                elapsed_time=$((current_time - start_time))
                
                if [ $elapsed_time -ge $TIMEOUT ]; then
                    echo "Timeout: Pod $DB_POD_NAME did not run within $TIMEOUT seconds"
                    break
                fi
                
                echo "Waiting for pod $DB_POD_NAME to be running..."
                sleep 5 # Wait for 5 seconds before checking again
            fi
        done

        # Copy files to db service
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/ssl/root.crt $DB_POD_NAME:/tmp/var/lib/ssl/server.crt -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/ssl/root.key $DB_POD_NAME:/tmp/var/lib/ssl/server.key -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/realtime.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/migrations/99-realtime.sql -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/webhooks.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/init-scripts/98-webhooks.sql -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/roles.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/init-scripts/99-roles.sql -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/jwt.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/_supabase.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/migrations/97-_supabase.sql -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/logs.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/migrations/99-logs.sql -c init-db
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/db/pooler.sql $DB_POD_NAME:/tmp/docker-entrypoint-initdb.d/migrations/99-pooler.sql -c init-db
    fi

    KONG_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^kong.*Init" | awk '{print $1}' | head -n 1)
    if [[ -z "$KONG_POD_NAME" ]]; then
        echo "No pod found with label service=kong"
    else
        start_time=$(date +%s)
        while true; do
            # Check if the pod is running
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod $KONG_POD_NAME -n $NAMESPACE -o jsonpath='{.status.initContainerStatuses[*].state}')
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $KONG_POD_NAME is running"
                break
            else
                current_time=$(date +%s)
                elapsed_time=$((current_time - start_time))
                
                if [ $elapsed_time -ge $TIMEOUT ]; then
                    echo "Timeout: Pod $KONG_POD_NAME did not run within $TIMEOUT seconds"
                    break
                fi
                
                echo "Waiting for pod $KONG_POD_NAME to be running..."
                sleep 5 # Wait for 5 seconds before checking again
            fi
        done

        # Copy files to kong service
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/api/kong.yml $KONG_POD_NAME:/tmp/home/kong/temp.yml -c init-kong
    fi

    SUPAVISOR_POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods --no-headers=true | grep "^supavisor.*Init" | awk '{print $1}' | head -n 1)
    if [[ -z "$SUPAVISOR_POD_NAME" ]]; then
        echo "No pod found with label service=supavisor"
    else
        start_time=$(date +%s)
        while true; do
            # Check if the pod is running
            status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pod $SUPAVISOR_POD_NAME -n $NAMESPACE -o jsonpath='{.status.initContainerStatuses[*].state}')
            status_key=$(echo "$status" | sed 's/^{"\([^"]*\)":.*/\1/')
            if [ "$status_key" = "running" ]; then
                echo "Pod $SUPAVISOR_POD_NAME is running"
                break
            else
                current_time=$(date +%s)
                elapsed_time=$((current_time - start_time))
                
                if [ $elapsed_time -ge $TIMEOUT ]; then
                    echo "Timeout: Pod $SUPAVISOR_POD_NAME did not run within $TIMEOUT seconds"
                    break
                fi
                
                echo "Waiting for pod $SUPAVISOR_POD_NAME to be running..."
                sleep 5 # Wait for 5 seconds before checking again
            fi
        done

        # Copy files to supavisor service
        kubectl --kubeconfig="$KUBECONFIG_PATH" cp ./volumes/pooler/pooler.exs $SUPAVISOR_POD_NAME:/tmp/etc/pooler/pooler.exs -c init-supavisor
    fi

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