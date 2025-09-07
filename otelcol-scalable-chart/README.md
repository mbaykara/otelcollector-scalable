# Otel-Collectors

OpenTelemetry Collector stack for Kubernetes observability with Grafana Cloud

**Chart Version:** 1.0.0 
**Application Version:** 0.133.0

## Overview

This Helm chart deploys a production-ready, scalable OpenTelemetry Collector stack on Kubernetes with comprehensive security hardening and multi-destination OTLP support.

### Architecture

The chart implements a **multi-tier collector architecture** optimized for high-throughput observability:

#### Application Observability Collectors
- **receiver**: OTLP data ingestion (deployment, configurable replicas)
- **tailsampling**: Intelligent trace sampling (statefulset for consistency)
- **spanmetrics**: Trace-to-metrics conversion (statefulset for aggregation)
- **servicegraph**: Service topology generation (statefulset for state management)

#### Infrastructure Observability Collectors 
- **cluster-metrics**: Kubernetes cluster-level metrics (statefulset with target allocator)
- **node-metrics**: Node-level system metrics (daemonset for per-node collection)

## 🚀 Quick Start

### Prerequisites

- Kubernetes 1.28+
- Helm 3.15+
- OpenTelemetry Operator installed in cluster

### Installation

1. **Create namespace:**
   ```bash
   kubectl create namespace o11y
   ```

2. **Create authentication secrets:**
   ```bash
   kubectl create secret generic grafana-cloud-secret \
     --from-literal=username=YOUR_USERNAME \
     --from-literal=password=YOUR_PASSWORD \
     -n o11y
   ```

3. **Install the chart:**
   ```bash
   helm install otel-collectors oci://your-registry/otel-collectors \
     --set global.clusterName=YOUR_CLUSTER_NAME \
     --set otlpDestinations.grafanaCloud.endpoint=YOUR_ENDPOINT \
     --namespace o11y
   ```

## ⚙️ Configuration

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.clusterName` | Kubernetes cluster identifier | `kind-cluster` |
| `global.environment` | Deployment environment | `production` |
| `global.namespace` | Target namespace | `o11y` |

### OTLP Destinations

This chart supports multiple OTLP destinations for flexible telemetry routing:

```yaml
otlpDestinations:
  grafanaCloud:
    enabled: true
    endpoint: "https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
    authSecretName: "grafana-cloud-secret"
    signals: ["traces", "metrics", "logs"]
```

### 🔒 Security Configuration

The chart implements **Pod Security Standards "restricted" level** with comprehensive hardening:

#### Pod Security Context
```yaml
security:
  podSecurityContext:
    runAsUser: 65534              # Nobody user (non-root)
    runAsGroup: 65534             # Nobody group 
    runAsNonRoot: true            # Enforce non-root execution
    fsGroup: 65534                # File system group ownership
    fsGroupChangePolicy: "OnRootMismatch"  # Efficient group changes
    seccompProfile:
      type: RuntimeDefault        # Runtime default seccomp profile
```

#### Container Security Context
```yaml
security:
  containerSecurityContext:
    runAsNonRoot: true            # Prevent root execution
    readOnlyRootFilesystem: true  # Read-only root filesystem
    allowPrivilegeEscalation: false  # Block privilege escalation
    privileged: false             # Not a privileged container
    capabilities:
      drop: ["ALL"]               # Drop all Linux capabilities
    seccompProfile:
      type: RuntimeDefault        # Default seccomp filtering
```

#### Advanced Security Settings
- **Pod Security Standard**: `restricted` (highest security level)
- **Host Network Access**: `false` (isolated from host)
- **Allowed Volume Types**: `configMap`, `secret`, `emptyDir`, `projected`, `downwardAPI`

### Collector Configuration

#### Application Collectors

**Receiver Collector:**
- **Type**: application, **Mode**: deployment
- **Purpose**: OTLP data ingestion and load balancing
- **Resources**: 512Mi memory, 500m CPU limits

**Tail Sampling Collector:**
- **Type**: application, **Mode**: statefulset 
- **Purpose**: Intelligent trace sampling with configurable policies
- **Resources**: 8Gi memory, 2 CPU for high-throughput processing

**Span Metrics Collector:**
- **Type**: application, **Mode**: statefulset
- **Purpose**: Generate metrics from trace spans
- **Resources**: 4Gi memory for span aggregation

**Service Graph Collector:**
- **Type**: application, **Mode**: statefulset
- **Purpose**: Create service topology from traces
- **Resources**: 4Gi memory for relationship mapping

#### Infrastructure Collectors

**Cluster Metrics Collector:**
- **Type**: infrastructure, **Mode**: statefulset
- **Purpose**: Kubernetes cluster-level metrics via k8s_cluster receiver
- **Features**: Target allocator enabled for Prometheus scraping

**Node Metrics Collector:**
- **Type**: infrastructure, **Mode**: daemonset
- **Purpose**: Per-node system metrics via kubeletstats
- **Resources**: 512Mi memory, optimized for node-level collection

### Health Probes

Health monitoring is **enabled** with production-ready settings:

**Readiness Probe:**
- Initial Delay: 10s, Period: 10s, Timeout: 5s, Failure Threshold: 3

**Liveness Probe:**
- Initial Delay: 30s, Period: 30s, Timeout: 10s, Failure Threshold: 3

## 📊 Observability Features

### Metric Collection

The chart includes optimized allowlists for:
- **cAdvisor**: Container metrics
- **Kubelet**: Node and pod metrics 
- **Kube-State-Metrics**: Kubernetes object state
- **Node Exporter**: System-level metrics
- **Kubeletstats**: Kubelet statistics
- **OTel Collector**: Self-monitoring metrics

### Dependencies

- **Kube-State-Metrics**: Kubernetes object metrics (optional)
- **Node Exporter**: System metrics collection (configurable)

## 🛠️ Advanced Configuration

### Tail Sampling Policies

Configure intelligent trace sampling with multiple policy types:

```yaml
applicationObservability:
  tailsampling:
    policies:
      enabled: true
      list:
        # Sample all error traces
        - name: errors-policy
          type: status_code
          status_code:
            status_codes: [ERROR, UNSET]
       
        # Sample slow requests (>2s)
        - name: latency-policy
          type: latency
          latency:
            threshold_ms: 2000
       
        # Probabilistic sampling for normal traces
        - name: probabilistic-policy
          type: probabilistic
          probabilistic:
            sampling_percentage: 5
```

### Custom Security Profiles

Enable custom security profiles for enhanced protection:

```yaml
security:
  advanced:
    annotations:
      container.apparmor.security.beta.kubernetes.io/otel-collector: "runtime/default"
    seccompProfiles:
      custom:
        type: Localhost
        localhostProfile: "profiles/otel-collector.json"
```

### Resource Optimization

Optimize resource allocation based on throughput requirements:

```yaml
collectors:
  receiver:
    resources:
      limits:
        memory: 2Gi    # High memory for ingestion
        cpu: 1000m
      requests:
        memory: 1Gi
        cpu: 500m
 
  tailsampling:
    replicas: 3        # Scale for decision processing
    resources:
      limits:
        memory: 8Gi    # Large memory for trace buffering
```

## 🔧 Troubleshooting

### Common Issues

1. **Schema Validation Errors**
   ```bash
   helm lint ./otel-collectors --strict
   ```

2. **Security Context Failures**
   ```bash
   kubectl describe pod -n o11y -l app.kubernetes.io/name=otel-collectors
   ```

3. **OTLP Connectivity Issues**
   ```bash
   kubectl logs -n o11y deployment/otel-collectors-receiver
   ```

### Validation

The chart includes comprehensive validation to prevent misconfigurations:
- **Pre-deployment validation**: Enabled by default
- **Schema validation**: 650+ validation rules in `values.schema.json`
- **Security compliance**: Pod Security Standards enforcement

## 📝 Values Reference

### Complete Values Schema

The chart uses JSON Schema validation to ensure configuration correctness. Key validation rules:

- **Security**: Non-root users (1-65534), read-only filesystem, no privilege escalation
- **Resources**: Memory format `512Mi|1Gi|1.5Gi`, CPU limits as strings or numbers
- **Networking**: HTTPS endpoints only, Kubernetes-valid names
- **Collectors**: Valid modes (`deployment|statefulset|daemonset`), 1-10 replicas

### Example Production Configuration

```yaml
global:
  clusterName: "production-k8s"
  environment: "production"
  namespace: "observability"

otlpDestinations:
  grafanaCloud:
    enabled: true
    endpoint: "https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
    authSecretName: "grafana-cloud-credentials"
    signals: ["traces", "metrics", "logs"]

security:
  advanced:
    podSecurityStandard: "restricted"

collectors:
  receiver:
    replicas: 3
    resources:
      limits:
        memory: 2Gi
        cpu: 1
 
  tailsampling:
    replicas: 5
    resources:
      limits:
        memory: 8Gi
        cpu: 2
```

## 🤝 Contributing

### Development Workflow

This chart uses a comprehensive Makefile for development and testing. Here are the key targets:

#### 🎯 Key Make Targets:

**Quick Development**
```bash
make lint          # Lint chart with schema validation
make test          # Run all tests
make docs          # Generate README.md from template
make dev           # Quick development workflow
```

**CI/CD Pipeline**
```bash
make ci            # Complete CI pipeline
make all           # Full test suite with kind cluster
```

**Kind Cluster Testing**
```bash
make kind-install  # Install in kind cluster
make kind-test     # Full kind cluster test
make kind-delete   # Clean up kind cluster
```

### Contributing Guidelines

1. **Security First**: Follow Pod Security Standards "restricted" level
2. **Schema Validation**: Update `values.schema.json` for new configuration fields
3. **Testing**: Run `make ci` before submitting PRs
4. **Documentation**: README.md is auto-generated from `README.md.gotmpl`
5. **Validation**: All changes must pass `helm lint --strict`

### Development Setup

```bash
# Install dependencies
make install-deps

# Quick development cycle
make dev

# Full validation before commit
make ci

# Test in real cluster
make kind-test
```

### Pull Request Checklist

- [ ] `make ci` passes without errors
- [ ] Security context compliance maintained
- [ ] Schema validation updated for new fields
- [ ] Documentation template updated if needed
- [ ] Kind cluster testing successful
- [ ] Breaking changes documented

## 📄 License

**Maintainers:**
- Mehmet Ali Baykara (mehmetalibaykara@gmail.com)

---

Generated with helm-docs on 2025-09-07 20:30:50 UTC