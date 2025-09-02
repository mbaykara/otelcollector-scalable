#!/bin/bash
# Script to generate OpenTelemetry Collector configurations with allowlist regex patterns
# Usage: ./generate-collector-configs.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLISTS_DIR="${SCRIPT_DIR}/allowLists"

# Function to generate regex from allowlist YAML file
generate_regex() {
    local allowlist_file="$1"
    if [[ ! -f "$allowlist_file" ]]; then
        echo "Error: Allowlist file $allowlist_file not found" >&2
        return 1
    fi
    
    # Extract allowlist items and join with pipe separator
    if command -v yq >/dev/null 2>&1; then
        yq eval '.allowlist | join("|")' "$allowlist_file"
    else
        # Fallback: use grep and sed
        grep -E '^\s*-\s+' "$allowlist_file" | \
            sed 's/^\s*-\s*//' | \
            tr '\n' '|' | \
            sed 's/|$//'
    fi
}

# Generate regex patterns from allowlists
echo "Generating regex patterns from allowlists..."

KUBELET_REGEX=$(generate_regex "$ALLOWLISTS_DIR/kubelet.yaml")
CADVISOR_REGEX=$(generate_regex "$ALLOWLISTS_DIR/cadvisor.yaml")
KUBE_STATE_METRICS_REGEX=$(generate_regex "$ALLOWLISTS_DIR/kube-state-metrics.yaml")
NODE_EXPORTER_REGEX=$(generate_regex "$ALLOWLISTS_DIR/node-exporter.yaml")
KUBELETSTATS_REGEX=$(generate_regex "$ALLOWLISTS_DIR/kubeletstats.yaml")
OTEL_COLLECTOR_REGEX=$(generate_regex "$ALLOWLISTS_DIR/otel-collector.yaml")

echo "✅ Generated regex patterns"

# Function to generate collector config from template
generate_collector_config() {
    local template_file="$1"
    local output_file="$2"
    
    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template file $template_file not found" >&2
        return 1
    fi
    
    echo "Generating $output_file from template..."
    
    # Generate final collector config from template
    sed \
        -e "s@{{CADVISOR_REGEX}}@${CADVISOR_REGEX}@g" \
        -e "s@{{KUBELET_REGEX}}@${KUBELET_REGEX}@g" \
        -e "s@{{KUBE_STATE_METRICS_REGEX}}@${KUBE_STATE_METRICS_REGEX}@g" \
        -e "s@{{OTEL_COLLECTOR_REGEX}}@${OTEL_COLLECTOR_REGEX}@g" \
        -e "s@{{KUBELETSTATS_REGEX}}@${KUBELETSTATS_REGEX}@g" \
        -e "s@{{NODE_EXPORTER_REGEX}}@${NODE_EXPORTER_REGEX}@g" \
        "$template_file" > "$output_file"
    
    echo "✅ Generated $output_file"
}

# Generate collector configurations from templates
echo "Generating collector configurations..."

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/generated-manifests"
mkdir -p "$OUTPUT_DIR"

# Template and output file paths
CLUSTER_TEMPLATE="$SCRIPT_DIR/templates/collector-k8s-cluster.yaml.template"
NODES_TEMPLATE="$SCRIPT_DIR/templates/collector-k8s-nodes.yaml.template"
CLUSTER_OUTPUT="$OUTPUT_DIR/collector-k8s-cluster.yaml"
NODES_OUTPUT="$OUTPUT_DIR/collector-k8s-nodes.yaml"

if [[ -f "$CLUSTER_TEMPLATE" ]]; then
    generate_collector_config "$CLUSTER_TEMPLATE" "$CLUSTER_OUTPUT"
fi

if [[ -f "$NODES_TEMPLATE" ]]; then
    generate_collector_config "$NODES_TEMPLATE" "$NODES_OUTPUT"
fi

echo ""
echo "🎉 Collector configurations generated with allowlist regex patterns!"
echo ""
echo "Generated files in $OUTPUT_DIR:"
echo "  - collector-k8s-cluster.yaml"
echo "  - collector-k8s-nodes.yaml"
echo ""
echo "To apply the configurations:"
echo "kubectl apply -f $OUTPUT_DIR/"