#!/bin/bash
# Script to convert existing collector configurations to templates with allowlist placeholders
# Usage: ./convert-to-templates.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# Create templates directory
mkdir -p "$TEMPLATES_DIR"

echo "Converting collector configurations to templates..."

# Convert collector-k8s-cluster.yaml to template
if [[ -f "$SCRIPT_DIR/collector-k8s-cluster.yaml" ]]; then
    echo "Converting collector-k8s-cluster.yaml to template..."
    
    # Read the file and replace hardcoded regex patterns with placeholders
    sed \
        -e 's|go_goroutines|kubelet_certificate_manager_client_expiration_renew_errors.*|{{KUBELET_REGEX}}|g' \
        -e 's|kube_configmap_info|kube_node.*|kube_node_info.*|{{KUBE_STATE_METRICS_REGEX}}|g' \
        "$SCRIPT_DIR/collector-k8s-cluster.yaml" > "$TEMPLATES_DIR/collector-k8s-cluster.yaml.template"
    
    echo "✅ Created template: $TEMPLATES_DIR/collector-k8s-cluster.yaml.template"
fi

# Convert collector-k8s-nodes.yaml to template  
if [[ -f "$SCRIPT_DIR/collector-k8s-nodes.yaml" ]]; then
    echo "Converting collector-k8s-nodes.yaml to template..."
    
    # For kubeletstats, replace any existing regex patterns
    sed \
        -e 's|k8s_node_.*|k8s_pod_.*|k8s_container_.*|{{KUBELETSTATS_REGEX}}|g' \
        "$SCRIPT_DIR/collector-k8s-nodes.yaml" > "$TEMPLATES_DIR/collector-k8s-nodes.yaml.template"
    
    echo "✅ Created template: $TEMPLATES_DIR/collector-k8s-nodes.yaml.template"
fi

echo ""
echo "🎉 Template conversion complete!"
echo "📁 Templates created in: $TEMPLATES_DIR/"
echo ""
echo "Next steps:"
echo "1. Edit templates to add {{REGEX_NAME}} placeholders where needed"
echo "2. Run ./generate-collector-configs.sh to generate final configurations"