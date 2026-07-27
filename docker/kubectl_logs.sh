#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/kubectl_setup_args.sh"

: "${KUBECONFIG_PATH:?KUBECONFIG_PATH is required (-c flag or env var)}"
: "${NAMESPACE:=default}"
: "${TAIL_LINES:=100}"
: "${POD_NAME:=}"

export KUBECONFIG="${KUBECONFIG_PATH}"

echo "=============================================="
echo "Kubernetes Pod Logs Report"
echo "Namespace: ${NAMESPACE}"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=============================================="

# Function to get logs for a pod
get_pod_logs() {
    local pod="$1"
    local status="$2"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Pod: ${pod}"
    echo "Status: ${status}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get current logs
    echo ""
    echo "--- Current Logs (last ${TAIL_LINES} lines) ---"
    if ! kubectl logs "${pod}" -n "${NAMESPACE}" --tail="${TAIL_LINES}" 2>/dev/null; then
        echo "(No current logs available)"
    fi
    
    # For crashed/restarting pods, also get previous logs
    if [[ "${status}" == *"CrashLoopBackOff"* ]] || [[ "${status}" == *"Error"* ]] || [[ "${status}" == *"OOMKilled"* ]]; then
        echo ""
        echo "--- Previous Container Logs (last ${TAIL_LINES} lines) ---"
        if ! kubectl logs "${pod}" -n "${NAMESPACE}" --previous --tail="${TAIL_LINES}" 2>/dev/null; then
            echo "(No previous logs available)"
        fi
    fi
}

# If a specific pod is requested, only show that pod
if [[ -n "${POD_NAME}" ]]; then
    status=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    get_pod_logs "${POD_NAME}" "${status}"
    exit 0
fi

echo ""
echo "=== Pod Status Summary ==="
echo ""
kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || echo "No pods found in namespace '${NAMESPACE}'"

# Get unhealthy pods first (CrashLoopBackOff, Error, Pending, etc.)
echo ""
echo "=============================================="
echo "=== Unhealthy Pod Logs ==="
echo "=============================================="

unhealthy_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | awk '{print $1 "," $3}' || true)

if [[ -z "${unhealthy_pods}" ]]; then
    echo ""
    echo "No unhealthy pods found."
else
    while IFS=',' read -r pod status; do
        [[ -z "${pod}" ]] && continue
        get_pod_logs "${pod}" "${status}"
    done <<< "${unhealthy_pods}"
fi

# Get pods with restarts
echo ""
echo "=============================================="
echo "=== Pods With Restarts ==="
echo "=============================================="

# Get pods where restart count > 0
restarted_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '$4 > 0 && $3 == "Running" {print $1 "," $3 ",restarts=" $4}' || true)

if [[ -z "${restarted_pods}" ]]; then
    echo ""
    echo "No pods with restarts found."
else
    while IFS=',' read -r pod status restarts; do
        [[ -z "${pod}" ]] && continue
        get_pod_logs "${pod}" "${status} (${restarts})"
    done <<< "${restarted_pods}"
fi

# Optionally show all pod logs
if [[ "${SHOW_ALL_LOGS:-false}" == "true" ]]; then
    echo ""
    echo "=============================================="
    echo "=== All Pod Logs ==="
    echo "=============================================="
    
    all_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{print $1 "," $3}' || true)
    
    while IFS=',' read -r pod status; do
        [[ -z "${pod}" ]] && continue
        get_pod_logs "${pod}" "${status}"
    done <<< "${all_pods}"
fi

echo ""
echo "=============================================="
echo "Pod Logs Report Complete"
echo "=============================================="
