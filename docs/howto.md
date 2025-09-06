# Configuration Guide

This guide covers advanced configuration options for the OpenTelemetry Collector Stack.

## Multi-Destination Setup

### Basic Configuration

Configure multiple OTLP destinations to route telemetry data:

```yaml
otlpDestinations:
  grafanaCloud:
    enabled: true
    endpoint: "https://otlp-gateway-prod-eu-west-2.grafana.net/otlp"
    authSecretName: "grafana-cloud-auth"
    usernameKey: "username"
    passwordKey: "password"
    signals: ["traces", "metrics", "logs"]
  
  jaeger:
    enabled: true
    endpoint: "http://jaeger:4318"
    authSecretName: "jaeger-auth"
    usernameKey: "username"
    passwordKey: "password"
    signals: ["traces"]
    
  loki:
    enabled: true
    endpoint: "http://loki:3100/otlp"
    authSecretName: "loki-auth"
    usernameKey: "username"
    passwordKey: "password"
    signals: ["logs"]
```

### Signal-Specific Routing

Route different signal types to specialized backends:

```yaml
otlpDestinations:
  # Traces to Jaeger
  jaeger:
    enabled: true
    endpoint: "http://jaeger:4318"
    authSecretName: "jaeger-auth"
    signals: ["traces"]
    
  # Metrics to Prometheus
  prometheus:
    enabled: true
    endpoint: "http://prometheus:3100/otlp/v1/write"
    authSecretName: "prometheus-auth"
    signals: ["metrics"]
    
  # Logs to Loki
  loki:
    enabled: true
    endpoint: "http://loki:3100/otlp"
    authSecretName: "loki-auth"
    signals: ["logs"]
```

### Authentication Setup

Create secrets for each destination:

```bash
# Grafana Cloud
kubectl create secret generic grafana-cloud-auth \
  --from-literal=username="YOUR_GRAFANA_USERNAME" \
  --from-literal=password="YOUR_GRAFANA_TOKEN" \
  -n o11y

# Jaeger
kubectl create secret generic jaeger-auth \
  --from-literal=username="YOUR_JAEGER_USERNAME" \
  --from-literal=password="YOUR_JAEGER_PASSWORD" \
  -n o11y
```

## Transform Processors

Configure span name normalization per component:

```yaml
applicationObservability:
  receiver:
    transform:
      traces:
        enabled: true
        transforms:
          span:
            - replace_pattern(span.name, "^GET /api/cart.*", "GET /api/cart")
            - replace_pattern(span.name, "^GET /api/users/\\d+", "GET /api/users/{id}")
  
  spanmetrics:
    transform:
      traces:
        enabled: true
        transforms:
          span:
            - replace_pattern(span.name, "^GET /media/.*", "GET /media/image")
```

## Tail Sampling Policies

### Basic Policies

```yaml
applicationObservability:
  tailsampling:
    policies:
      enabled: true
      list:
        # Always sample errors
        - name: errors-always
          type: status_code
          status_code:
            status_codes: [ERROR]
        
        # Sample slow requests
        - name: slow-requests
          type: latency
          latency:
            threshold_ms: 2000
        
        # Probabilistic sampling
        - name: sample-rest
          type: probabilistic
          probabilistic:
            sampling_percentage: 5
```

### Complex Policies

```yaml
        # Complex AND policy
        - name: critical-service-errors
          type: and
          and:
            and_sub_policy:
              - name: service-filter
                type: string_attribute
                string_attribute:
                  key: service.name
                  values: [auth-service, payment-service]
              - name: error-filter
                type: status_code
                status_code:
                  status_codes: [ERROR]
        
        # Rate limiting
        - name: rate-limit-rest
          type: rate_limiting
          rate_limiting:
            spans_per_second: 100
```

### Supported Policy Types

| Policy Type | Description | Use Case |
|-------------|-------------|----------|
| `always_sample` | Always sample specific traces | Critical services |
| `latency` | Sample based on response time | Performance monitoring |
| `numeric_attribute` | Sample based on numeric values | Transaction amounts |
| `probabilistic` | Random percentage sampling | General sampling |
| `status_code` | Sample based on HTTP/gRPC status | Error tracking |
| `string_attribute` | Sample based on string matching | Service filtering |
| `rate_limiting` | Limit sampling throughput | Cost control |
| `span_count` | Sample based on trace complexity | Complex operations |
| `trace_state` | Sample based on trace state | Trace propagation |
| `boolean_attribute` | Sample based on boolean flags | Feature flags |
| `ottl_condition` | Sample using OTTL expressions | Custom logic |
| `and` | Logical AND of multiple policies | Complex conditions |
| `composite` | Multiple evaluation criteria | Advanced routing |

## Component Configuration

### Collector Resources

Adjust resources based on your throughput:

```yaml
collectors:
  receiver:
    resources:
      limits:
        memory: 2Gi
        cpu: 1
      requests:
        memory: 1Gi
        cpu: 500m
  
  tailsampling:
    replicas: 2
    resources:
      limits:
        memory: 2Gi
        cpu: 1
      requests:
        memory: 1Gi
        cpu: 500m
```

### Histogram Configuration

Configure custom histogram buckets:

```yaml
histograms:
  buckets: [0.1s, 0.5s, 1s, 2s, 5s, 10s, 30s]
```

## Troubleshooting

### Common Issues

1. **"ERROR: otlpDestinations.X.endpoint is required"**
   - Ensure all enabled destinations have valid `endpoint` URLs
   - URLs must start with `http://` or `https://`

2. **Authentication failures**
   - Verify secrets exist: `kubectl get secret <secret-name> -n o11y`
   - Check secret keys match `usernameKey`/`passwordKey` values
   - Verify credentials are correct for each destination

3. **No telemetry data reaching destinations**
   - Check collector logs: `kubectl logs -n o11y deployment/otel-collectors-tailsampling-collector`
   - Verify `signals` array contains expected telemetry types
   - Confirm destination endpoints are reachable from cluster

### Debugging Commands

```bash
# Check collector health
kubectl get opentelemetrycollectors -n o11y

# View collector configuration
kubectl get configmap -n o11y -o yaml | grep -A 50 "collector.yaml"

# Check collector logs
kubectl logs -f -n o11y deployment/otel-collectors-receiver-collector

# Test connectivity
kubectl run test-client --rm -i --restart=Never --image=curlimages/curl -- \
  curl -X POST "http://otel-collectors-receiver-collector.o11y.svc.cluster.local:4318/v1/traces" \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

## Migration Guide

### From Single Grafana Cloud to Multi-Destination

**Old configuration:**
```yaml
grafanaCloud:
  endpoint: "https://otlp-gateway.grafana.net/otlp"
  authSecretName: "grafana-auth"
```

**New configuration:**
```yaml
otlpDestinations:
  grafanaCloud:
    enabled: true
    endpoint: "https://otlp-gateway.grafana.net/otlp"
    authSecretName: "grafana-auth"
    usernameKey: "username"  # Add this
    passwordKey: "password"  # Add this  
    signals: ["traces", "metrics", "logs"]  # Add this
```

**Required changes:**
1. Move `grafanaCloud` config under `otlpDestinations.grafanaCloud`
2. Add `usernameKey` and `passwordKey` fields
3. Add `signals` array to specify which telemetry types to send
4. Ensure secret has keys matching `usernameKey`/`passwordKey` values

## Performance Tuning

### High-Throughput Environments

For high-throughput scenarios, adjust these settings:

```yaml
collectors:
  receiver:
    replicas: 3
    resources:
      limits:
        memory: 4Gi
        cpu: 2
  
  tailsampling:
    replicas: 5
    config:
      decisionWait: "10s"
      samplingRate: 0.1  # 10% sampling
```

### Memory Optimization

```yaml
collectorsCommon:
  resources:
    limits:
      memory: 1Gi
    requests:
      memory: 512Mi
```

Configure memory limiter:
```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 75
    spike_limit_percentage: 25
```