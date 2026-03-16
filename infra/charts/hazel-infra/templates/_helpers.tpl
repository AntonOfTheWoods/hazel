
{{/*
Return the proper Image Registry Secret Names
*/}}
{{- define "hazel.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.global.image) "context" $) -}}
{{- end -}}

{{/*
Create a default fully qualified postgresql name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.postgresql.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) -}}
{{- end -}}

{{/*
Create a default fully qualified redis name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.redis.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "redis" "chartValues" .Values.redis "context" $) -}}
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
Get the Redis&reg; credentials secret.
*/}}
{{- define "hazel.redis.secretName" -}}
{{- if .Values.redis.enabled -}}
    {{- $name := default "redis" .Values.redis.nameOverride -}}
    {{- default (printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-") (tpl .Values.redis.auth.existingSecret $) -}}
{{- else }}
    {{- default (printf "%s-externalredis" .Release.Name) (tpl .Values.externalRedis.existingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Get the Postgresql credentials secret.
*/}}
{{- define "hazel.postgresql.secretName" -}}
{{- if .Values.postgresql.enabled }}
    {{- tpl (coalesce (((.Values.global).postgresql).auth).existingSecret .Values.postgresql.auth.existingSecret (include "hazel.postgresql.fullname" .)) $ -}}
{{- else -}}
    {{- default (printf "%s-externaldb" .Release.Name) (tpl .Values.externalDatabase.existingSecret $) -}}
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
