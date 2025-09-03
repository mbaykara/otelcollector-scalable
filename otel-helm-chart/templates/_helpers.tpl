{{/*
Expand the name of the chart.
*/}}
{{- define "otel-collectors.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "otel-collectors.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "otel-collectors.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "otel-collectors.labels" -}}
helm.sh/chart: {{ include "otel-collectors.chart" . }}
{{ include "otel-collectors.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "otel-collectors.selectorLabels" -}}
app.kubernetes.io/name: {{ include "otel-collectors.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate allowlist regex pattern from YAML file
*/}}
{{- define "otel-collectors.allowlistRegex" -}}
{{- $root := index . 0 -}}
{{- $allowlistName := index . 1 -}}
{{- $allowlistFile := printf "allowlists/%s.yaml" $allowlistName -}}
{{- $content := $root.Files.Get $allowlistFile -}}
{{- if $content -}}
{{- $allowlist := $content | fromYaml -}}
{{- if $allowlist.allowlist -}}
{{- $allowlist.allowlist | join "|" -}}
{{- else -}}
{{- printf ".*" -}}
{{- end -}}
{{- else -}}
{{- printf ".*" -}}
{{- end -}}
{{- end }}

{{/*
Cadvisor allowlist regex
*/}}
{{- define "otel-collectors.cadvisorRegex" -}}
{{- include "otel-collectors.allowlistRegex" (list . "cadvisor") -}}
{{- end }}

{{/*
Kubelet allowlist regex
*/}}
{{- define "otel-collectors.kubeletRegex" -}}
{{- include "otel-collectors.allowlistRegex" (list . "kubelet") -}}
{{- end }}

{{/*
Kube-state-metrics allowlist regex
*/}}
{{- define "otel-collectors.kubeStateMetricsRegex" -}}
{{- include "otel-collectors.allowlistRegex" (list . "kube-state-metrics") -}}
{{- end }}

{{/*
Node-exporter allowlist regex
*/}}
{{- define "otel-collectors.nodeExporterRegex" -}}
{{- include "otel-collectors.allowlistRegex" (list . "node-exporter") -}}
{{- end }}

{{/*
Kubeletstats allowlist regex
*/}}
{{- define "otel-collectors.kubeletstatsRegex" -}}
{{- include "otel-collectors.allowlistRegex" (list . "kubeletstats") -}}
{{- end }}

{{/*
OTel Collector allowlist regex
*/}}
{{- define "otel-collectors.otelCollectorRegex" -}}
{{- include "otel-collectors.allowlistRegex" (list . "otel-collector") -}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "otel-collectors.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "otel-collectors.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate collector configuration based on type and config
*/}}
{{- define "otel-collectors.collectorConfig" -}}
{{- $collector := .collector -}}
{{- $name := .name -}}
{{- $global := .global -}}
{{- $root := .root -}}
receivers:
  {{- if has "otlp" $collector.config.receivers }}
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  {{- end }}
  {{- if has "k8s_cluster" $collector.config.receivers }}
  k8s_cluster:
    auth_type: serviceAccount
    collection_interval: 10s
    node_conditions_to_report:
      - Ready
      - MemoryPressure
      - DiskPressure
      - PIDPressure
    distribution: kubernetes
    allocatable_types_to_report:
      - cpu
      - memory
      - ephemeral-storage
  {{- end }}
  {{- if has "kubeletstats" $collector.config.receivers }}
  kubeletstats:
    collection_interval: 20s
    auth_type: serviceAccount
    endpoint: ${env:K8S_NODE_NAME}:10250
    insecure_skip_verify: true
    extra_metadata_labels:
      - container.id
      - k8s.volume.type
    metric_groups:
      - container
      - pod
      - node
      - volume
  {{- end }}
processors:
  {{- if has "memory_limiter" $collector.config.processors }}
  memory_limiter:
    check_interval: 1s
    limit_percentage: 75
    spike_limit_percentage: 25
  {{- end }}
  {{- if has "resource" $collector.config.processors }}
  resource:
    attributes:
    - key: cluster
      value: {{ $global.global.clusterName }}
      action: insert
    - key: workloadName
      value: {{ $collector.config.workloadName | quote }}
      action: insert
  {{- end }}
  {{- if has "batch" $collector.config.processors }}
  batch:
    send_batch_size: 1000
    timeout: 10s
  {{- end }}
exporters:
  {{- if has "otlphttp/grafanacloud" $collector.config.exporters }}
  otlphttp/grafanacloud:
    endpoint: {{ $global.grafanaCloud.endpoint }}
    auth:
      authenticator: basicauth/grafanacloud
  {{- end }}
extensions:
  basicauth/grafanacloud:
    client_auth:
      username: ${env:GRAFANA_USERNAME}
      password: ${env:GRAFANA_PASSWORD}
  health_check:
    endpoint: 0.0.0.0:13133
service:
  extensions: [basicauth/grafanacloud, health_check]
  pipelines:
    metrics:
      receivers: {{ $collector.config.receivers | toJson }}
      processors: {{ $collector.config.processors | toJson }}
      exporters: {{ $collector.config.exporters | toJson }}
  telemetry:
    logs:
      level: INFO
    metrics:
      level: detailed
      readers:
      - pull:
          exporter:
            prometheus:
              host: 0.0.0.0
              port: 8888
{{- end }}

