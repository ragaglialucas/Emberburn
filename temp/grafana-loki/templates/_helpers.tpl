{{/*
Expand the name of the chart.
*/}}
{{- define "postgresql-pod.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "postgresql-pod.fullname" -}}
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
{{- define "postgresql-pod.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "postgresql-pod.labels" -}}
helm.sh/chart: {{ include "postgresql-pod.chart" . }}
{{ include "postgresql-pod.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
fireball.industries/component: database
fireball.industries/part-of: postgresql
{{- end }}

{{/*
Selector labels
*/}}
{{- define "postgresql-pod.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql-pod.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "postgresql-pod.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "postgresql-pod.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "postgresql-pod.namespace" -}}
{{- default .Release.Namespace .Values.global.namespaceOverride }}
{{- end }}

{{/*
Get the selected preset
*/}}
{{- define "postgresql-pod.preset" -}}
{{- index .Values.resourcePresets .Values.resourcePreset }}
{{- end }}

{{/*
Get resource requests
*/}}
{{- define "postgresql-pod.resources" -}}
{{- $preset := include "postgresql-pod.preset" . | fromYaml }}
requests:
  cpu: {{ $preset.resources.requests.cpu }}
  memory: {{ $preset.resources.requests.memory }}
limits:
  cpu: {{ $preset.resources.limits.cpu }}
  memory: {{ $preset.resources.limits.memory }}
{{- end }}

{{/*
Get PostgreSQL configuration from preset
*/}}
{{- define "postgresql-pod.postgresqlConfig" -}}
{{- $preset := include "postgresql-pod.preset" . | fromYaml }}
max_connections = {{ .Values.postgresql.config.max_connections | default $preset.maxConnections }}
shared_buffers = {{ .Values.postgresql.config.shared_buffers | default $preset.sharedBuffers }}
effective_cache_size = {{ .Values.postgresql.config.effective_cache_size | default $preset.effectiveCacheSize }}
work_mem = {{ .Values.postgresql.config.work_mem | default $preset.workMem }}
maintenance_work_mem = {{ .Values.postgresql.config.maintenance_work_mem | default $preset.maintenanceWorkMem }}
{{- end }}

{{/*
PostgreSQL image
*/}}
{{- define "postgresql-pod.image" -}}
{{- printf "%s/%s:%s" .Values.global.image.registry .Values.global.image.repository .Values.global.image.tag }}
{{- end }}

{{/*
Get storage size from preset
*/}}
{{- define "postgresql-pod.storageSize" -}}
{{- $preset := include "postgresql-pod.preset" . | fromYaml }}
{{- .Values.persistence.size | default $preset.storage }}
{{- end }}

{{/*
Determine if HA is enabled
*/}}
{{- define "postgresql-pod.isHA" -}}
{{- if eq .Values.deploymentMode "ha" }}
{{- true }}
{{- else if .Values.highAvailability.enabled }}
{{- true }}
{{- else }}
{{- false }}
{{- end }}
{{- end }}

{{/*
Get replica count
*/}}
{{- define "postgresql-pod.replicas" -}}
{{- if eq (include "postgresql-pod.isHA" .) "true" }}
{{- .Values.highAvailability.replicas }}
{{- else }}
{{- 1 }}
{{- end }}
{{- end }}
