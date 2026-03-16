{{/* vim: set filetype=mustache: */}}

{{/*
Add environment variables to configure database values
*/}}
{{- define "hazel.database.host" -}}
{{- if eq .Values.postgresql.architecture "replication" }}
    {{- printf "%s-primary" (ternary (include "hazel.postgresql.fullname" .) (tpl .Values.externalDatabase.host $) .Values.postgresql.enabled) -}}
{{- else -}}
    {{- ternary (include "hazel.postgresql.fullname" .) (tpl .Values.externalDatabase.host $) .Values.postgresql.enabled -}}
{{- end -}}
{{- end -}}

{{/*
Add environment variables to configure database values
*/}}
{{- define "hazel.database.user" -}}
{{- if .Values.postgresql.enabled }}
    {{- default .Values.postgresql.auth.username (((.Values.global).postgresql).auth).username -}}
{{- else -}}
    {{- .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Add environment variables to configure database values
*/}}
{{- define "hazel.database.name" -}}
{{- if .Values.postgresql.enabled }}
    {{- default .Values.postgresql.auth.database (((.Values.global).postgresql).auth).database -}}
{{- else -}}
    {{- .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Add environment variables to configure database values
*/}}
{{- define "hazel.database.secretKey" -}}
{{- ternary "password" (tpl .Values.externalDatabase.existingSecretPasswordKey .) .Values.postgresql.enabled -}}
{{- end -}}

{{/*
Add environment variables to configure database values
*/}}
{{- define "hazel.database.port" -}}
{{- if .Values.postgresql.enabled -}}
    {{- default .Values.postgresql.primary.service.ports.postgresql ((((.Values.global).postgresql).service).ports).postgresql -}}
{{- else -}}
    {{- .Values.externalDatabase.port -}}
{{- end -}}
{{- end -}}

{{/*
Add environment variables to configure redis values
*/}}
{{- define "hazel.redis.host" -}}
{{- if .Values.redis.enabled -}}
    {{- printf "%s-master" (include "hazel.redis.fullname" .) -}}
{{- else -}}
    {{- printf "%s" (tpl .Values.externalRedis.host $) -}}
{{- end -}}
{{- end -}}

{{/*
Add environment variables to configure redis values
*/}}
{{- define "hazel.redis.port" -}}
{{- ternary .Values.redis.master.service.ports.redis .Values.externalRedis.port .Values.redis.enabled -}}
{{- end -}}

{{/*
Add environment variables to configure redis values
*/}}
{{- define "hazel.redis.secretKey" -}}
{{- ternary "redis-password" (tpl .Values.externalRedis.existingSecretPasswordKey .) .Values.redis.enabled -}}
{{- end -}}

{{/*
Add environment variables to configure database values
{{- define "hazel.configure.database" -}}
- name: hazel_DATABASE_HOST
  value: {{ include "hazel.database.host" . | quote }}
- name: hazel_DATABASE_PORT_NUMBER
  value: {{ include "hazel.database.port" . | quote }}
- name: hazel_DATABASE_NAME
  value: {{ include "hazel.database.name" . | quote }}
- name: hazel_DATABASE_USER
  value: {{ include "hazel.database.user" . | quote }}
{{- end -}}
*/}}


{{/*
Return the proper hazel psql image name
*/}}
{{- define "hazel.psql.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.psqlImage "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper hazel kv cli image name
*/}}
{{- define "hazel.kv.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.kvImage "global" .Values.global) }}
{{- end -}}

{{/*
reusable hazel db env vars
*/}}
{{- define "hazel.configure.database" }}
- name: PGDATABASE
  value: {{ .Values.db.name | quote }}
- name: PGHOST
  value: {{ .Values.db.host | quote }}
- name: PGPORT
  value: {{ .Values.db.port | quote }}
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.db.credentials }}
      key: username
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.db.credentials }}
      key: password
- name: PGSSLMODE
  value: {{ .Values.db.sslMode | default "disable" | quote }}

- name: DATABASE_URL
  value: "postgresql://$(PGUSER):$(PGPASSWORD)@$(PGHOST):$(PGPORT)/$(PGDATABASE)?sslmode=$(PGSSLMODE)"

{{- end -}}

{{/*
reusable hazel kv env vars
*/}}
{{- define "hazel.configure.kv" }}

- name: KV_DB
  value: {{ .Values.kv.db | quote }}
- name: KV_HOST
  value: {{ .Values.kv.host | quote }}
- name: KV_PORT
  value: {{ .Values.kv.port | quote }}
- name: KV_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.kv.credentials }}
      key: username
- name: KV_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.kv.credentials }}
      key: password
- name: KV_SSLMODE
  value: {{ .Values.kv.sslMode | default "disable" | quote }}

# FIXME: should be protocol independent, and at the very least handle rediss://
- name: KV_URL
  value: {{ printf "redis://$(KV_USER):$(KV_PASSWORD)@$(KV_HOST):$(KV_PORT)/$(KV_DB)" | quote }}
- name: REDIS_URL
  value: {{ printf "redis://$(KV_USER):$(KV_PASSWORD)@$(KV_HOST):$(KV_PORT)/$(KV_DB)" | quote }}
{{- end -}}

{{/*
reusable db check-db-ready
*/}}
{{- define "hazel.initContainers.waitForDB" }}
- name: wait-for-db
  image: {{ template "hazel.psql.image" . }}
  imagePullPolicy: {{ .Values.psqlImage.pullPolicy }}
  command: ['sh', '-c',
    'until psql -c "select 1;";
    do echo waiting for database; sleep 2; done;']
  env:
    {{ include "hazel.configure.database" . | indent 4 }}
{{- end -}}

{{/*
reusable wait-for-kv
*/}}
{{- define "hazel.initContainers.waitForKV" }}
- name: wait-for-kv
  image: {{ template "hazel.kv.image" . }}
  imagePullPolicy: {{ .Values.kv.pullPolicy }}
  command:
    - /bin/bash
  args:
    - -ec
    - |
        set -o errexit
        set -o nounset
        set -o pipefail

        KV_CLI=redis-cli

        until [[ "$(${KV_CLI} -h ${KV_HOST} -p ${KV_PORT_NUMBER} -a ${KV_PASSWORD} --user ${KV_USER} PING 2>/dev/null)" == "PONG" ]];
        do echo "Waiting for KV"; sleep 2; done;
        echo "Connected to the KV instance"


  env:
    {{ include "hazel.configure.kv" . | indent 4 }}
{{- end -}}
