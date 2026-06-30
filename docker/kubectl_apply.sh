source ./kubectl_setup_args.sh

if [ ! -d "./kubernetes/release/adminusers" ]; then
    mkdir -p "./kubernetes/release/adminusers"
    echo "Directory ./kubernetes/release/adminusers created."
else 
    echo "Directory ./kubernetes/release/adminusers already exists."
fi

if [ ! -d "./kubernetes/release/clusterroles" ]; then
    mkdir -p "./kubernetes/release/clusterroles"
    echo "Directory ./kubernetes/release/clusterroles created."
else 
    echo "Directory ./kubernetes/release/clusterroles already exists."
fi

if [ ! -d "./kubernetes/release/daemonsets" ]; then
    mkdir -p "./kubernetes/release/daemonsets"
    echo "Directory ./kubernetes/release/daemonsets created."
else 
    echo "Directory ./kubernetes/release/daemonsets already exists."
fi

if [ ! -d "./kubernetes/release/deployments" ]; then
    mkdir -p "./kubernetes/release/deployments"
    echo "Directory ./kubernetes/release/deployments created."
else 
    echo "Directory ./kubernetes/release/deployments already exists."
fi

if [ ! -d "./kubernetes/release/networkpolicies" ]; then
    mkdir -p "./kubernetes/release/networkpolicies"
    echo "Directory ./kubernetes/release/networkpolicies created."
else 
    echo "Directory ./kubernetes/release/networkpolicies already exists."
fi

if [ ! -d "./kubernetes/release/persistentvolumeclaims" ]; then
    mkdir -p "./kubernetes/release/persistentvolumeclaims"
    echo "Directory ./kubernetes/release/persistentvolumeclaims created."
else 
    echo "Directory ./kubernetes/release/persistentvolumeclaims already exists."
fi

if [ ! -d "./kubernetes/release/runtimeclasses" ]; then
    mkdir -p "./kubernetes/release/runtimeclasses"
    echo "Directory ./kubernetes/release/runtimeclasses created."
else 
    echo "Directory ./kubernetes/release/runtimeclasses already exists."
fi

if [ ! -d "./kubernetes/release/secrets" ]; then
    mkdir -p "./kubernetes/release/secrets"
    echo "Directory ./kubernetes/release/secrets created."
else 
    echo "Directory ./kubernetes/release/secrets already exists."
fi

if [ ! -d "./kubernetes/release/services" ]; then
    mkdir -p "./kubernetes/release/services"
    echo "Directory ./kubernetes/release/services created."
else 
    echo "Directory ./kubernetes/release/services already exists."
fi

source ./setup_password.sh
source ./setup_ssl.sh

IFS=' ' read -ra STACK_ARRAY <<< "$STACKS"

# Check if the directory exists, if not, create it
source ./kubectl_setup_templates.sh
source ./kubectl_apply_adminusers.sh
source ./kubectl_apply_clusterroles.sh
source ./kubectl_apply_daemonsets.sh
source ./kubectl_apply_secrets.sh
source ./kubectl_apply_persistentvolumeclaims.sh
source ./kubectl_apply_runtimeclasses.sh
source ./kubectl_apply_deployments.sh
source ./kubectl_apply_networkpolicies.sh
source ./kubectl_apply_services.sh

source ./setup_kong.sh
source ./setup_nginx.sh
source ./kubectl_setup_nginx.sh && kubectl_setup_nginx
source ./kubectl_setup_core.sh
source ./kubectl_setup_ai.sh

kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
kubectl --kubeconfig="$KUBECONFIG_PATH" proxy &

echo 'Dashboard token:'
kubectl --kubeconfig="$KUBECONFIG_PATH" get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d

exit 0