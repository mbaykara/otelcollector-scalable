# Otel-Collectors

OpenTelemetry Collector stack for Kubernetes observability with Grafana Cloud

**Chart Version:** 1.0.0  
**Application Version:** 0.133.0

## Overview

This Helm chart deploys a production-ready, scalable OpenTelemetry Collector stack on Kubernetes with comprehensive security hardening and multi-destination OTLP support.

### Architecture

The chart implements a **multi-tier collector architecture** optimized for high-throughput observability:

#### Application Observability Collectors
- **receiver**: receiver (deployment, 1 replicas)
- **tailsampling**: tailsampling (statefulset, 2 replicas)  
- **spanmetrics**: spanmetrics (statefulset, 2 replicas)
- **servicegraph**: servicegraph (statefulset, 2 replicas)

#### Infrastructure Observability Collectors  
- **cluster-metrics**: cluster (statefulset, 3 replicas)
- **node-metrics**: nodes (daemonset, 1 replicas)

## 🚀 Quick Start

### Prerequisites

- Kubernetes 1.28+
- Helm 3.8+
- OpenTelemetry Operator installed in cluster

### Installation

1. **Create namespace:**
   ```bash
   kubectl create namespace o11y
   ```

2. **Create authentication secrets:**
   ```bash
   kubectl create secret generic otlp-grafana-net-auth \
     --from-literal=username=YOUR_USERNAME \
     --from-literal=password=YOUR_PASSWORD \
     -n o11y
   
   kubectl create secret generic otlp-azure-foobar-auth \
     --from-literal=username=YOUR_USERNAME \
     --from-literal=password=YOUR_PASSWORD \
     -n o11y
   ```

3. **Install the chart:**
   ```bash
   helm install otel-collectors oci://your-registry/otel-collectors \
     --set global.clusterName=YOUR_CLUSTER_NAME \
     --set otlpDestinations.grafanaCloud.endpoint=YOUR_ENDPOINT \
     --set otlpDestinations.azurefoobar.endpoint=YOUR_ENDPOINT \
     --namespace o11y
   ```

## ⚙️ Configuration

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.clusterName` | Kubernetes cluster identifier | `""` |
| `global.environment` | Deployment environment | `"production"` |
| `global.namespace` | Target namespace | `o11y` |

### OTLP Destinations

This chart supports multiple OTLP destinations for flexible telemetry routing:

#### Grafana Cloud
```yaml
otlpDestinations:
  grafanaCloud:
    enabled: true
    endpoint: ""
    authSecretName: ""
    signals: ["traces", "metrics", "logs"]
```

### 🔒 Security Configuration

The chart implements **Pod Security Standards "restricted" level** with comprehensive hardening:

#### Pod Security Context
```yaml
security:
  podSecurityContext:
    runAsUser: 65534
    runAsGroup: 65534
    runAsNonRoot: true
    fsGroup: 65534
    fsGroupChangePolicy: "OnRootMismatch"
    seccompProfile:
      type: RuntimeDefault
```

#### Container Security Context
```yaml
security:
  containerSecurityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    privileged: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
```

#### Advanced Security Settings
- **Pod Security Standard**: restricted
- **Host Network Access**: false
- **Allowed Volume Types**: configMap, secret, emptyDir, projected, downwardAPI

### Collector Configuration

#### Receiver Collector

**Type:** application  
**Mode:** deployment  
**Replicas:** 1

**Resources:**
```yaml
resources:
  limits:
    memory: 512Mi
    cpu: 500m
  requests:
    memory: 256Mi
    cpu: 200m
```

**Configuration:**
- **Workload Name:** receiver
- **Receivers:** otlp, filelog
- **Processors:** memory_limiter, k8sattributes, resource, batch
- **Exporters:** loadbalancing, loadbalancing/spanmetrics, loadbalancing/servicegraph

#### Tailsampling Collector

**Type:** application  
**Mode:** statefulset  
**Replicas:** 2

**Resources:**
```yaml
resources:
  limits:
    memory: 8Gi
    cpu: 500m
  requests:
    memory: 1Gi
    cpu: 200m
```

**Configuration:**
- **Workload Name:** tailsampling
- **Receivers:** otlp
- **Processors:** memory_limiter, resource/add_workload_name, tail_sampling, batch
- **Exporters:** otlphttp/grafanacloud
- **Sampling Rate:** 0.5%
- **Decision Wait:** 10s

### Health Probes

Health monitoring is **enabled** with the following configuration:

**Readiness Probe:**
- Initial Delay: 10s
- Period: 10s  
- Timeout: 5s
- Failure Threshold: 3

**Liveness Probe:**
- Initial Delay: 30s
- Period: 30s
- Timeout: 10s
- Failure Threshold: 3

## 📊 Observability Features

### Metric Collection

The chart includes allowlists for optimized metric collection:

- **Cadvisor**: Enabled
- **Kubelet**: Enabled
- **Kube-State-Metrics**: Enabled
- **Node-Exporter**: Enabled
- **Kubeletstats**: Enabled
- **Otel-Collector**: Enabled

### Dependencies

- **Node Exporter**: true (node-exporter)

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

- **Pre-deployment validation**: ✅ Enabled
- **Operator check**: ✅ Enabled
- **Connectivity test**: ✅ Enabled

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

1. Follow security best practices
2. Update schema validation for new fields
3. Test with `helm lint --strict`
4. Document breaking changes

## 📄 License

**Maintainers:**
- Platform Team (platform@company.com)

---

*This README was generated from the Go template at: `README.md.gotmpl`*
*To regenerate: Use helm-docs or process the template manually*