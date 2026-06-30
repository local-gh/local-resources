#!/bin/bash

manifest_replicas() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    grep -E '^[[:space:]]+replicas:' "$file" | head -1 | awk '{print $2}'
}

manifest_resource_name() {
    local file="$1"
    grep -E '^[[:space:]]+name:' "$file" | head -1 | awk '{print $2}'
}

restart_deployment_if_replicas() {
    local replicas="${1:-0}"
    local grep_pattern="$2"
    local kubeconfig="$3"

    if [[ "${replicas}" -le 0 ]]; then
        echo "Skipping restart for ${grep_pattern} (replicas=0)"
        return
    fi

    local name
    name="$(kubectl --kubeconfig="$kubeconfig" get deployments --no-headers=true | grep "^${grep_pattern}" | awk '{print $1}' | head -n 1)"
    if [[ -n "$name" ]]; then
        kubectl --kubeconfig="$kubeconfig" rollout restart deployment "$name" -n default
    fi
}
