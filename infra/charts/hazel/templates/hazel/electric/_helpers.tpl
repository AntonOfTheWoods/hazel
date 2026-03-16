{{- define "electric.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.electric.image "global" .Values.global) }}
{{- end -}}

{{/*
Create a default fully qualified name for electric component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "electric.fullname" -}}
{{- printf "%s-electric" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
