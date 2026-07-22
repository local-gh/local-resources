kubectl_cleanup_terminated_pods() {
    local kubeconfig="${KUBECONFIG_PATH:?KUBECONFIG_PATH is required}"
    local deleted=0
    local ns name phase

    echo "Cleaning up terminated / failed pods..."

    # Phase-based: Failed and Succeeded (Completed Jobs, crashed pods, etc.)
    while IFS=$'\t' read -r ns name; do
        [[ -z "$ns" || -z "$name" ]] && continue
        echo "Force deleting ${ns}/${name} (phase Failed/Succeeded)"
        kubectl --kubeconfig="$kubeconfig" delete pod "$name" -n "$ns" \
            --force --grace-period=0 --ignore-not-found
        deleted=$((deleted + 1))
    done < <(
        kubectl --kubeconfig="$kubeconfig" get pods -A \
            --field-selector=status.phase==Failed \
            -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' 2>/dev/null
        kubectl --kubeconfig="$kubeconfig" get pods -A \
            --field-selector=status.phase==Succeeded \
            -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' 2>/dev/null
    )

    # Status-based leftovers (Evicted, Error, Unknown) and pods stuck Terminating
    while read -r ns name phase; do
        [[ -z "$ns" || -z "$name" ]] && continue
        echo "Force deleting ${ns}/${name} (status=${phase})"
        kubectl --kubeconfig="$kubeconfig" delete pod "$name" -n "$ns" \
            --force --grace-period=0 --ignore-not-found
        deleted=$((deleted + 1))
    done < <(
        kubectl --kubeconfig="$kubeconfig" get pods -A --no-headers 2>/dev/null \
            | awk '
                $4 == "Error" ||
                $4 == "Evicted" ||
                $4 == "ContainerStatusUnknown" ||
                $4 == "NodeLost" ||
                $0 ~ /Terminating/ {
                    print $1, $2, $4
                }'
    )

    if [ "$deleted" -eq 0 ]; then
        echo "No terminated pods to delete"
    else
        echo "Force deleted ${deleted} terminated pod(s)"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source ./kubectl_setup_args.sh
    kubectl_cleanup_terminated_pods
fi
