{{/*
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper hazel image name
*/}}
{{- define "hazel.web.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.web.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "hazel.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.web.image) "context" $) -}}
{{- end -}}

{{/*
Create a default fully qualified name for hazel web component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.web.fullname" -}}
{{- printf "%s-web" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified name for hazel Celery worker component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.worker.fullname" -}}
{{- printf "%s-worker" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "hazel.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Get the secret name
*/}}
{{- define "hazel.secretName" -}}
{{- default (include "common.names.fullname" .) (tpl .Values.auth.existingSecret .) -}}
{{- end -}}

{{/*
Get the configmap name
*/}}
{{- define "hazel.configMapName" -}}
{{- default (printf "%s-configuration" (include "common.names.fullname" .)) (tpl .Values.existingConfigmap .) -}}
{{- end -}}

{{/*
Add environment variables to configure hazel common values
*/}}
{{- define "hazel.configure.common" -}}
- name: IS_DEV
  value: {{ .Values.isDev }}
{{- end -}}
