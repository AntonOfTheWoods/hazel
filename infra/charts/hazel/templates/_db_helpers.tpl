{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper hazel image name
*/}}
{{- define "hazel.psql.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.psqlImage "global" .Values.global) }}
{{- end -}}

{{/*
reusable hazel db env vars
*/}}
{{- define "hazel.database.envvars" }}
- name: PGDATABASE
  value: {{ .Values.hazel.db.name | quote }}
- name: PGHOST
  value: {{ .Values.hazel.db.host | quote }}
- name: PGPORT
  value: {{ .Values.hazel.db.port | quote }}
- name: PGUSER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.db.credentials }}
      key: username
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.db.credentials }}
      key: password
- name: PGSSLMODE
  value: {{ .Values.hazel.db.sslMode | default "disable" | quote }}

- name: DATABASE_URL
  value: "postgresql://$(PGUSER):$(PGPASSWORD)@$(PGHOST):$(PGPORT)/$(PGDATABASE)?sslmode=$(PGSSLMODE)"

{{- end -}}

{{/*
reusable hazel kv env vars
*/}}
{{- define "hazel.kv.envvars" }}

- name: KV_DB
  value: {{ .Values.hazel.kv.db | quote }}
- name: KV_HOST
  value: {{ .Values.hazel.kv.host | quote }}
- name: KV_PORT
  value: {{ .Values.hazel.kv.port | quote }}
- name: KV_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.kv.credentials }}
      key: username
- name: KV_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.kv.credentials }}
      key: password
- name: KV_SSLMODE
  value: {{ .Values.hazel.kv.sslMode | default "disable" | quote }}

# FIXME: should be protocol independent, and at the very least handle rediss://
- name: KV_URL
  value: {{ printf "redis://$(KV_USER):$(KV_PASSWORD)@$(KV_HOST):$(KV_PORT)/$(KV_DB)" | quote }}
- name: REDIS_URL
  value: {{ printf "redis://$(KV_USER):$(KV_PASSWORD)@$(KV_HOST):$(KV_PORT)/$(KV_DB)" | quote }}
{{- end -}}


{{/*
reusable db check-db-ready
*/}}
{{- define "hazel.database.checkdbready" }}
- name: check-hazel-db-ready
  image: {{ template "hazel.psql.image" . }}
  imagePullPolicy: {{ .Values.psqlImage.pullPolicy }}
  command: ['sh', '-c',
    'until psql -c "select 1;";
    do echo waiting for database; sleep 2; done;']
  env:
    {{ include "hazel.database.envvars" . | indent 4 }}
{{- end -}}
