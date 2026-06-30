ENV_FILE="${ENV_FILE:-.env}"
if [ ! -f "$ENV_FILE" ] && [ -f "../.env" ]; then
    ENV_FILE="../.env"
fi
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found"
    exit 1
fi
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
done < "$ENV_FILE"

source ./kubectl_replicas_helpers.sh

envsubst < kubernetes/Chart.tpl.yaml > kubernetes/Chart.yaml
envsubst < kubernetes/values.tpl.yaml > kubernetes/values.yaml

helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/services/nginx-service.yaml" > kubernetes/release/services/nginx-service.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/deployments/nginx-deployment.yaml" > kubernetes/release/deployments/nginx-deployment.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/persistentvolumeclaims/nginx-persistentvolumeclaim.yaml" > kubernetes/release/persistentvolumeclaims/nginx-persistentvolumeclaim.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/persistentvolumeclaims/nginx-ssl-persistentvolumeclaim.yaml" > kubernetes/release/persistentvolumeclaims/nginx-ssl-persistentvolumeclaim.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/deployments/nginx-deployment.yaml" > kubernetes/release/deployments/nginx-deployment.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/daemonsets/nvidia-device-plugin-daemonset.yaml" > kubernetes/release/daemonsets/nvidia-device-plugin-daemonset.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/adminusers/dashboard-adminuser.yaml" > kubernetes/release/adminusers/dashboard-adminuser.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/clusterroles/dashboard-clusterrole.yaml" > kubernetes/release/clusterroles/dashboard-clusterrole.yaml
helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/secrets/dashboard-secret.yaml" > kubernetes/release/secrets/dashboard-secret.yaml

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"
# Deploy services based on STACKS
for stack in "${STACK_ARRAY[@]}"; do
    adminusers_paths=$(find ./kubernetes/templates/adminusers -type f -name "${stack}-*")
    for path in $adminusers_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/adminusers/$filename" > kubernetes/release/adminusers/$filename
    done

    clusterroles_paths=$(find ./kubernetes/templates/clusterroles -type f -name "${stack}-*")
    for path in $clusterroles_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/clusterroles/$filename" > kubernetes/release/clusterroles/$filename
    done

    daemonsets_paths=$(find ./kubernetes/templates/daemonsets -type f -name "${stack}-*")
    for path in $daemonsets_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/daemonsets/$filename" > kubernetes/release/daemonsets/$filename
    done

    deployments_paths=$(find ./kubernetes/templates/deployments -type f -name "${stack}-*")
    for path in $deployments_paths; do
        filename=$(basename "$path")
        temp_file="$(mktemp)"
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/deployments/$filename" > "$temp_file"
        replicas="$(manifest_replicas "$temp_file")"
        if [[ "${replicas:-0}" -gt 0 ]]; then
            mv "$temp_file" kubernetes/release/deployments/$filename
        else
            rm -f "$temp_file"
            rm -f kubernetes/release/deployments/$filename
            echo "Skipping deployment manifest $filename (replicas=0)"
        fi
    done

    networkpolicies_paths=$(find ./kubernetes/templates/networkpolicies -type f -name "${stack}-*")
    for path in $networkpolicies_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/networkpolicies/$filename" > kubernetes/release/networkpolicies/$filename
    done

    persistentvolumeclaims_paths=$(find ./kubernetes/templates/persistentvolumeclaims -type f -name "${stack}-*")
    for path in $persistentvolumeclaims_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/persistentvolumeclaims/$filename" > kubernetes/release/persistentvolumeclaims/$filename
    done

    runtimeclasses_paths=$(find ./kubernetes/templates/runtimeclasses -type f -name "${stack}-*")
    for path in $runtimeclasses_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/runtimeclasses/$filename" > kubernetes/release/runtimeclasses/$filename
    done

    secrets_paths=$(find ./kubernetes/templates/secrets -type f -name "${stack}-*")
    for path in $secrets_paths; do
        filename=$(basename "$path")
        helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/secrets/$filename" > kubernetes/release/secrets/$filename
    done

    services_paths=$(find ./kubernetes/templates/services -type f -name "${stack}-*")
    for path in $services_paths; do
        filename=$(basename "$path")
        deployment_filename="${filename/-service.yaml/-deployment.yaml}"
        if [[ -f kubernetes/release/deployments/$deployment_filename ]]; then
            helm template "$PROJECT_NAME" "./kubernetes" --show-only "templates/services/$filename" > kubernetes/release/services/$filename
        else
            rm -f kubernetes/release/services/$filename
            echo "Skipping service manifest $filename (deployment replicas=0)"
        fi
    done
done