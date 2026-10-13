#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/kubectl_setup_args.sh"

: "${KUBECONFIG_PATH:?KUBECONFIG_PATH is required (-c flag or env var)}"
: "${NAMESPACE:=default}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "=============================================="
echo "Kubernetes Cluster Monitoring Report"
echo "Namespace: ${NAMESPACE}"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=============================================="

echo ""
echo "=== Node Memory Usage ==="
echo ""
if kubectl top nodes 2>/dev/null; then
    :
else
    echo "Warning: metrics-server may not be installed. 'kubectl top' requires metrics-server."
    echo "Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
fi

echo ""
echo "=== Pod Memory Usage (sorted by memory) ==="
echo ""
if kubectl top pods -n "${NAMESPACE}" --sort-by=memory 2>/dev/null; then
    :
else
    echo "Warning: Could not retrieve pod metrics. metrics-server may not be installed or namespace '${NAMESPACE}' may not exist."
fi

echo ""
echo "=== Pod Distribution Across Nodes ==="
echo ""
kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || echo "No pods found in namespace '${NAMESPACE}'"

echo ""
echo "=== Node Resource Allocation ==="
echo ""
kubectl describe nodes | grep -A 20 "Allocated resources" 2>/dev/null || echo "Could not retrieve node resource allocation details"

echo ""
echo "=============================================="
echo "Monitoring Report Complete"
echo "=============================================="
