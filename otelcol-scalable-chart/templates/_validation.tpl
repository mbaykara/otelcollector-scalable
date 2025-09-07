{{/*
Critical validation functions for OpenTelemetry Collector Chart
*/}}

{{/*
Validate required global configuration
*/}}
{{- define "otel-collectors.validateGlobal" -}}
{{- if not .Values.global.clusterName -}}
{{- fail "ERROR: global.clusterName is required and cannot be empty" -}}
{{- end -}}
{{- if not .Values.global.namespace -}}
{{- fail "ERROR: global.namespace is required and cannot be empty" -}}
{{- end -}}
{{- if not (regexMatch "^[a-z0-9-]+$" .Values.global.clusterName) -}}
{{- fail "ERROR: global.clusterName must contain only lowercase letters, numbers, and hyphens" -}}
{{- end -}}
{{- if not (regexMatch "^[a-z0-9-]+$" .Values.global.namespace) -}}
{{- fail "ERROR: global.namespace must contain only lowercase letters, numbers, and hyphens" -}}
{{- end -}}
{{- end -}}

{{/*
Validate OTLP Destinations configuration
*/}}
{{- define "otel-collectors.validateOtlpDestinations" -}}
{{- $enabledDestinations := 0 -}}
{{- range $destName, $dest := .Values.otlpDestinations -}}
{{- if $dest.enabled -}}
  {{- $enabledDestinations = add $enabledDestinations 1 -}}
  {{- if not $dest.endpoint -}}
    {{- fail (printf "ERROR: otlpDestinations.%s.endpoint is required and cannot be empty" $destName) -}}
  {{- end -}}
  {{- if not (hasPrefix "http" $dest.endpoint) -}}
    {{- fail (printf "ERROR: otlpDestinations.%s.endpoint must use HTTP or HTTPS protocol" $destName) -}}
  {{- end -}}
  {{- if not $dest.authSecretName -}}
    {{- fail (printf "ERROR: otlpDestinations.%s.authSecretName is required and cannot be empty" $destName) -}}
  {{- end -}}
  {{- if not $dest.usernameKey -}}
    {{- fail (printf "ERROR: otlpDestinations.%s.usernameKey is required and cannot be empty" $destName) -}}
  {{- end -}}
  {{- if not $dest.passwordKey -}}
    {{- fail (printf "ERROR: otlpDestinations.%s.passwordKey is required and cannot be empty" $destName) -}}
  {{- end -}}
  {{- if not $dest.signals -}}
    {{- fail (printf "ERROR: otlpDestinations.%s.signals is required and cannot be empty" $destName) -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- if eq $enabledDestinations 0 -}}
  {{- fail "ERROR: At least one OTLP destination must be enabled" -}}
{{- end -}}
{{- end -}}

{{/*
Validate collector mode configurations
*/}}
{{- define "otel-collectors.validateCollectorModes" -}}
{{- range $name, $collector := .Values.collectors -}}
{{- if $collector.enabled -}}
  {{- if eq $name "tailsampling" -}}
    {{- if ne $collector.mode "statefulset" -}}
      {{- fail (printf "ERROR: collector '%s' must use 'statefulset' mode for proper trace sampling" $name) -}}
    {{- end -}}
  {{- end -}}
  {{- if eq $name "spanmetrics" -}}
    {{- if ne $collector.mode "statefulset" -}}
      {{- fail (printf "ERROR: collector '%s' must use 'statefulset' mode for proper span aggregation" $name) -}}
    {{- end -}}
  {{- end -}}
  {{- if eq $name "servicegraph" -}}
    {{- if ne $collector.mode "statefulset" -}}
      {{- fail (printf "ERROR: collector '%s' must use 'statefulset' mode for proper service graph generation" $name) -}}
    {{- end -}}
  {{- end -}}
  {{- if eq $name "node-metrics" -}}
    {{- if ne $collector.mode "daemonset" -}}
      {{- fail (printf "ERROR: collector '%s' must use 'daemonset' mode for node-level metrics collection" $name) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate replica counts
*/}}
{{- define "otel-collectors.validateReplicas" -}}
{{- range $name, $collector := .Values.collectors -}}
{{- if $collector.enabled -}}
  {{- if and $collector.replicas (lt ($collector.replicas | int) 1) -}}
    {{- fail (printf "ERROR: collector '%s' must have at least 1 replica" $name) -}}
  {{- end -}}
  {{- if and $collector.replicas (gt ($collector.replicas | int) 10) -}}
    {{- fail (printf "ERROR: collector '%s' cannot have more than 10 replicas (current: %d)" $name ($collector.replicas | int)) -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate tailsampling specific configuration
*/}}
{{- define "otel-collectors.validateTailsampling" -}}
{{- if index .Values.collectors "tailsampling" "enabled" -}}
  {{- $ts := index .Values.collectors "tailsampling" -}}
  {{- if $ts.config -}}
    {{- if and $ts.config.samplingRate (or (lt ($ts.config.samplingRate | float64) 0.001) (gt ($ts.config.samplingRate | float64) 1.0)) -}}
      {{- fail (printf "ERROR: tailsampling samplingRate must be between 0.001 and 1.0 (current: %f)" ($ts.config.samplingRate | float64)) -}}
    {{- end -}}
    {{- if and $ts.config.decisionWait (not (regexMatch "^[0-9]+[smh]$" $ts.config.decisionWait)) -}}
      {{- fail (printf "ERROR: tailsampling decisionWait must be a valid duration (e.g., 10s, 1m, 1h), got: %s" $ts.config.decisionWait) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate resource configurations
*/}}
{{- define "otel-collectors.validateResources" -}}
{{- range $name, $collector := .Values.collectors -}}
{{- if and $collector.enabled $collector.resources -}}
  {{- if $collector.resources.requests -}}
    {{- if and $collector.resources.requests.memory (not (regexMatch "^[0-9]+\\.?[0-9]*[KMGT]i$" $collector.resources.requests.memory)) -}}
      {{- fail (printf "ERROR: collector '%s' memory request must be in format like '512Mi', '1Gi', '1.5Gi'" $name) -}}
    {{- end -}}
  {{- end -}}
  {{- if $collector.resources.limits -}}
    {{- if and $collector.resources.limits.memory (not (regexMatch "^[0-9]+\\.?[0-9]*[KMGT]i$" $collector.resources.limits.memory)) -}}
      {{- fail (printf "ERROR: collector '%s' memory limit must be in format like '512Mi', '1Gi', '1.5Gi'" $name) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate at least one collector is enabled
*/}}
{{- define "otel-collectors.validateEnabled" -}}
{{- $enabledCount := 0 -}}
{{- range $name, $collector := .Values.collectors -}}
  {{- if $collector.enabled -}}
    {{- $enabledCount = add $enabledCount 1 -}}
  {{- end -}}
{{- end -}}
{{- if eq $enabledCount 0 -}}
  {{- fail "ERROR: At least one collector must be enabled" -}}
{{- end -}}
{{- end -}}

{{/*
Validate receiver collector dependency
*/}}
{{- define "otel-collectors.validateReceiverDependency" -}}
{{- $receiverEnabled := false -}}
{{- if index .Values.collectors "receiver" "enabled" -}}
  {{- $receiverEnabled = true -}}
{{- end -}}
{{- $needsReceiver := false -}}
{{- range $name, $collector := .Values.collectors -}}
  {{- if and $collector.enabled (ne $name "receiver") (ne $name "cluster-metrics") (ne $name "node-metrics") -}}
    {{- $needsReceiver = true -}}
  {{- end -}}
{{- end -}}
{{- if and $needsReceiver (not $receiverEnabled) -}}
  {{- fail "ERROR: 'receiver' collector must be enabled when using tailsampling, spanmetrics, or servicegraph collectors" -}}
{{- end -}}
{{- end -}}

{{/*
Validate security configuration
*/}}
{{- define "otel-collectors.validateSecurity" -}}
{{- /* Validate pod security context */ -}}
{{- if not .Values.security.podSecurityContext.runAsNonRoot -}}
  {{- fail "ERROR: security.podSecurityContext.runAsNonRoot must be true for security compliance" -}}
{{- end -}}
{{- if eq (.Values.security.podSecurityContext.runAsUser | int) 0 -}}
  {{- fail "ERROR: security.podSecurityContext.runAsUser cannot be 0 (root user)" -}}
{{- end -}}
{{- if not (has .Values.security.podSecurityContext.seccompProfile.type (list "RuntimeDefault" "Localhost")) -}}
  {{- fail "ERROR: security.podSecurityContext.seccompProfile.type must be 'RuntimeDefault' or 'Localhost'" -}}
{{- end -}}

{{- /* Validate container security context */ -}}
{{- if not .Values.security.containerSecurityContext.runAsNonRoot -}}
  {{- fail "ERROR: security.containerSecurityContext.runAsNonRoot must be true for security compliance" -}}
{{- end -}}
{{- if not .Values.security.containerSecurityContext.readOnlyRootFilesystem -}}
  {{- fail "ERROR: security.containerSecurityContext.readOnlyRootFilesystem must be true for security compliance" -}}
{{- end -}}
{{- if .Values.security.containerSecurityContext.allowPrivilegeEscalation -}}
  {{- fail "ERROR: security.containerSecurityContext.allowPrivilegeEscalation must be false" -}}
{{- end -}}
{{- if .Values.security.containerSecurityContext.privileged -}}
  {{- fail "ERROR: security.containerSecurityContext.privileged must be false" -}}
{{- end -}}
{{- if eq (.Values.security.containerSecurityContext.runAsUser | int) 0 -}}
  {{- fail "ERROR: security.containerSecurityContext.runAsUser cannot be 0 (root user)" -}}
{{- end -}}
{{- if not (has "ALL" .Values.security.containerSecurityContext.capabilities.drop) -}}
  {{- fail "ERROR: security.containerSecurityContext.capabilities.drop must include 'ALL'" -}}
{{- end -}}
{{- if not (has .Values.security.containerSecurityContext.seccompProfile.type (list "RuntimeDefault" "Localhost")) -}}
  {{- fail "ERROR: security.containerSecurityContext.seccompProfile.type must be 'RuntimeDefault' or 'Localhost'" -}}
{{- end -}}

{{- /* Validate advanced security settings */ -}}
{{- if .Values.security.advanced.hostNetwork -}}
  {{- fail "ERROR: security.advanced.hostNetwork must be false for security compliance" -}}
{{- end -}}
{{- if not (has .Values.security.advanced.podSecurityStandard (list "baseline" "restricted" "privileged")) -}}
  {{- fail "ERROR: security.advanced.podSecurityStandard must be 'baseline', 'restricted', or 'privileged'" -}}
{{- end -}}
{{- end -}}

{{/*
Run all critical validations
*/}}
{{- define "otel-collectors.runValidations" -}}
{{- include "otel-collectors.validateGlobal" . -}}
{{- include "otel-collectors.validateOtlpDestinations" . -}}
{{- include "otel-collectors.validateCollectorModes" . -}}
{{- include "otel-collectors.validateReplicas" . -}}
{{- include "otel-collectors.validateTailsampling" . -}}
{{- include "otel-collectors.validateResources" . -}}
{{- include "otel-collectors.validateSecurity" . -}}
{{- include "otel-collectors.validateEnabled" . -}}
{{- include "otel-collectors.validateReceiverDependency" . -}}
{{- end -}}