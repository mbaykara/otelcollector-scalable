# Application Collectors

OpenTelemetry Collectors for processing application telemetry data.

## Components

- **collector-receiver.yaml** - Receives OTLP data from applications  
- **collector-spanmetrics.yaml** - Generates metrics from trace spans
- **collector-servicegraph.yaml** - Creates service topology from traces
- **collector-tailsampling.yaml** - Applies tail sampling to traces

## Deploy

```bash
kubectl apply -f .
```