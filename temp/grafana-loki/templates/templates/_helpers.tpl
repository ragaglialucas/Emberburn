{{/*
Expand the name of the chart.
*/}}
{{- define "grafana-loki.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "grafana-loki.fullname" -}}
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
{{- define "grafana-loki.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "grafana-loki.labels" -}}
helm.sh/chart: {{ include "grafana-loki.chart" . }}
{{ include "grafana-loki.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
fireball.industries/pod-type: grafana-loki
{{- end }}

{{/*
Selector labels
*/}}
{{- define "grafana-loki.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grafana-loki.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: observability
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "grafana-loki.serviceAccountName" -}}
{{- if .Values.pod.serviceAccount.create }}
{{- default (include "grafana-loki.fullname" .) .Values.pod.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.pod.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Namespace
*/}}
{{- define "grafana-loki.namespace" -}}
{{- if .Values.namespace.create }}
{{- .Values.namespace.name }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Grafana PVC name
*/}}
{{- define "grafana-loki.grafana.pvcName" -}}
{{- if .Values.grafana.persistence.existingClaim }}
{{- .Values.grafana.persistence.existingClaim }}
{{- else }}
{{- printf "%s-grafana" (include "grafana-loki.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Loki PVC name
*/}}
{{- define "grafana-loki.loki.pvcName" -}}
{{- if .Values.loki.persistence.existingClaim }}
{{- .Values.loki.persistence.existingClaim }}
{{- else }}
{{- printf "%s-loki" (include "grafana-loki.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Grafana resources
*/}}
{{- define "grafana-loki.grafana.resources" -}}
{{- if eq .Values.grafana.resources.preset "custom" }}
{{- toYaml .Values.grafana.resources.custom }}
{{- else }}
{{- $preset := index .Values.grafana.resources.presets .Values.grafana.resources.preset }}
{{- toYaml $preset }}
{{- end }}
{{- end }}

{{/*
Loki resources
*/}}
{{- define "grafana-loki.loki.resources" -}}
{{- if eq .Values.loki.resources.preset "custom" }}
{{- toYaml .Values.loki.resources.custom }}
{{- else }}
{{- $preset := index .Values.loki.resources.presets .Values.loki.resources.preset }}
{{- toYaml $preset }}
{{- end }}
{{- end }}

{{/*
Grafana admin password secret name
*/}}
{{- define "grafana-loki.grafana.secretName" -}}
{{- if .Values.grafana.admin.existingSecret }}
{{- .Values.grafana.admin.existingSecret }}
{{- else }}
{{- printf "%s-grafana-credentials" (include "grafana-loki.fullname" .) }}
{{- end }}
{{- end }}
