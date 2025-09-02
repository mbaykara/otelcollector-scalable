# Infrastructure Collectors

OpenTelemetry Collectors for Kubernetes infrastructure metrics with allowlist-based filtering.

## Components

- **allowLists/** - Metric allowlists for each data source
- **templates/** - Collector configuration templates  
- **generated-manifests/** - Final collector configurations (generated)

## Generate & Deploy

```bash
# Generate configurations from allowlists
./generate-collector-configs.sh

# Deploy collectors
kubectl apply -f generated-manifests/
```

## Collectors

- **collector-k8s-cluster** - Cluster-wide metrics (kube-state-metrics, kubelet, cAdvisor)
- **collector-k8s-nodes** - Node-level metrics (kubeletstats, node-exporter)