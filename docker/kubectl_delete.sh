source ./kubectl_setup_args.sh

if [ -n "$ENV_FILE" ]; then
    echo "Skipping env delete setup"
else
    ENV_FILE=".env"
    source ./kubectl_setup_env.sh
fi

helm template "$PROJECT_NAME" "./kubernetes" | kubectl delete -f -

kubectl --kubeconfig="$KUBECONFIG_PATH" delete deployments --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete pods --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete services --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete configmaps --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete secrets --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete replicasets --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete statefulsets --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete persistentvolumeclaims --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete jobs --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete cronjobs --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete daemonsets --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress --all --all-namespaces
kubectl --kubeconfig="$KUBECONFIG_PATH" delete networkpolicies --all --all-namespaces