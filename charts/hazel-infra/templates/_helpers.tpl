{{/*
Expand the name of the chart.
*/}}
{{- define "hazelinfra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common annotations that match Kustomize commonAnnotations
*/}}
{{- define "hazelinfra.annotations" -}}
app.kubernetes.io/version: {{ .Values.global.hazelVersion | quote }}
{{- with .Values.commonAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hazelinfra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hazelinfra.labels" -}}
helm.sh/chart: {{ include "hazelinfra.chart" . }}
app.kubernetes.io/name: {{ include "hazelinfra.name" . }}
app.kubernetes.io/instance: hazelinfra-{{ .Values.global.instanceId }}
app.kubernetes.io/version: {{ .Values.global.hazelVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: hazelinfra
{{- with .Values.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hazelinfra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hazelinfra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "hazelinfra.componentLabels" -}}
{{- $component := .component }}
{{- include "hazelinfra.labels" .root | nindent 0 }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Component-specific selector labels
*/}}
{{- define "hazelinfra.componentSelectorLabels" -}}
{{- $component := .component }}
app.kubernetes.io/name: {{ include "hazelinfra.name" .root }}
app.kubernetes.io/instance: hazelinfra-{{ .root.Values.global.instanceId }}
app.kubernetes.io/component: {{ $component }}
{{- end }}
