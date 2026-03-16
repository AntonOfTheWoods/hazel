{{/*
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper hazel image name
*/}}
{{- define "hazel.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "hazel.imagePullSecrets" -}}
{{- include "common.images.renderPullSecrets" (dict "images" (list .Values.image) "context" $) -}}
{{- end -}}

{{/*
Create a default fully qualified name for hazel web component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.web.fullname" -}}
{{- printf "%s-web" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified name for hazel Celery flower component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.flower.fullname" -}}
{{- printf "%s-flower" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified name for hazel Celery worker component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.worker.fullname" -}}
{{- printf "%s-worker" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified name for hazel Celery beat component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hazel.beat.fullname" -}}
{{- printf "%s-beat" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
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
Get the hazel Celery flower secret name
*/}}
{{- define "hazel.flower.secretName" -}}
{{- default (include "hazel.flower.fullname" .) (tpl .Values.flower.auth.existingSecret .) -}}
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
*/}}
{{- define "hazel.configure.database" -}}
- name: hazel_DATABASE_HOST
  value: {{ include "hazel.database.host" . | quote }}
- name: hazel_DATABASE_PORT_NUMBER
  value: {{ include "hazel.database.port" . | quote }}
- name: hazel_DATABASE_NAME
  value: {{ include "hazel.database.name" . | quote }}
- name: hazel_DATABASE_USER
  value: {{ include "hazel.database.user" . | quote }}
{{- if or (not .Values.postgresql.enabled) .Values.postgresql.auth.enablePostgresUser }}
{{- if .Values.usePasswordFiles }}
- name: hazel_DATABASE_PASSWORD_FILE
  value: {{ printf "/opt/bitnami/hazel/secrets/%s" (include "hazel.database.secretKey" .) }}
{{- else }}
- name: hazel_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "hazel.postgresql.secretName" . }}
      key: {{ include "hazel.database.secretKey" . }}
{{- end }}
{{- else }}
- name: ALLOW_EMPTY_PASSWORD
  value: "true"
{{- end }}
{{- end -}}

{{/*
Add environment variables to configure redis values
*/}}
{{- define "hazel.configure.redis" -}}
- name: REDIS_HOST
  value: {{ include "hazel.redis.host" . | quote }}
- name: REDIS_PORT_NUMBER
  value: {{ include "hazel.redis.port" . | quote }}
- name: REDIS_USER
  value: {{ ternary "default" .Values.externalRedis.username .Values.redis.enabled  | quote }}
{{- if .Values.usePasswordFiles }}
- name: REDIS_PASSWORD_FILE
  value: {{ printf "/opt/bitnami/hazel/secrets/%s" (include "hazel.redis.secretKey" .) }}
{{- else }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "hazel.redis.secretName" . }}
      key: {{ include "hazel.redis.secretKey" . }}
{{- end }}
{{- end -}}

{{/*
Add environment variables to configure hazel common values
*/}}
{{- define "hazel.configure.common" -}}
{{- if .Values.usePasswordFiles }}
- name: hazel_SECRET_KEY_FILE
  value: "/opt/bitnami/hazel/secrets/hazel-secret-key"
{{- else }}
- name: hazel_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "hazel.secretName" . }}
      key: hazel-secret-key
{{- end }}
{{- if or .Values.existingConfigmap .Values.config }}
- name: hazel_CONF_FILE
  value: "/bitnami/hazel/conf/hazel_config.py"
{{- end }}
- name: BITNAMI_DEBUG
  value: {{ ternary "true" "false" .Values.image.debug | quote }}
{{- end -}}

{{/*
Init container definition to wait for PostgreSQL
# NOTE: The value postgresql.image is not available unless postgresql.enabled is not set. We could change this to use os-shell if
# it had the binary wait-for-port.
*/}}
{{- define "hazel.initContainers.waitForDB" -}}
- name: wait-for-db
  image: {{ include "common.images.image" (dict "imageRoot" .Values.postgresql.image "global" .Values.global) }}
  imagePullPolicy: {{ .Values.postgresql.image.pullPolicy  }}
  {{- if .Values.defaultInitContainers.waitForDB.resources }}
  resources: {{ toYaml .Values.defaultInitContainers.waitForDB.resources | nindent 4 }}
  {{- else if ne .Values.defaultInitContainers.waitForDB.resourcesPreset "none" }}
  resources: {{- include "common.resources.preset" (dict "type" .Values.defaultInitContainers.waitForDB.resourcesPreset) | nindent 4 }}
  {{- end }}
  {{- if .Values.defaultInitContainers.waitForDB.containerSecurityContext.enabled }}
  securityContext: {{- include "common.compatibility.renderSecurityContext" (dict "secContext" .Values.defaultInitContainers.waitForDB.containerSecurityContext "context" $) | nindent 4 }}
  {{- end }}
  command:
    - /bin/bash
  args:
    - -ec
    - |
        set -o errexit
        set -o nounset
        set -o pipefail

        . /opt/bitnami/scripts/libos.sh
        . /opt/bitnami/scripts/liblog.sh
        . /opt/bitnami/scripts/libpostgresql.sh

        {{- if .Values.usePasswordFiles }}
        export hazel_DATABASE_PASSWORD="$(< $hazel_DATABASE_PASSWORD_FILE)"
        {{- end }}

        check_postgresql_connection() {
            echo "SELECT 1" | postgresql_remote_execute "$hazel_DATABASE_HOST" "$hazel_DATABASE_PORT_NUMBER" "$hazel_DATABASE_NAME" "$hazel_DATABASE_USER" "$hazel_DATABASE_PASSWORD"
        }

        info "Connecting to the PostgreSQL instance $hazel_DATABASE_HOST:$hazel_DATABASE_PORT_NUMBER"
        if ! retry_while "check_postgresql_connection"; then
            error "Could not connect to the database server"
            exit 1
        else
            info "Connected to the PostgreSQL instance"
        fi
  env:
    {{- include "hazel.configure.database" . | nindent 4 }}
  {{- if .Values.usePasswordFiles }}
  volumeMounts:
    - name: hazel-secrets
      mountPath: /opt/bitnami/hazel/secrets
      readOnly: true
  {{- end }}
{{- end -}}

{{/*
Init container definition to wait for Redis
*/}}
{{- define "hazel.initContainers.waitForRedis" -}}
# NOTE: The value redis.image is not available unless redis.enabled is not set. We could change this to use os-shell if
# it had the binary wait-for-port.
- name: wait-for-redis
  image: {{ include "common.images.image" (dict "imageRoot" .Values.redis.image "global" .Values.global) }}
  imagePullPolicy: {{ .Values.redis.image.pullPolicy | quote }}
  {{- if .Values.defaultInitContainers.waitForRedis.resources }}
  resources: {{ toYaml .Values.defaultInitContainers.waitForRedis.resources | nindent 4 }}
  {{- else if ne .Values.defaultInitContainers.waitForRedis.resourcesPreset "none" }}
  resources: {{- include "common.resources.preset" (dict "type" .Values.defaultInitContainers.waitForRedis.resourcesPreset) | nindent 4 }}
  {{- end }}
  {{- if .Values.defaultInitContainers.waitForRedis.containerSecurityContext.enabled }}
  securityContext: {{- include "common.compatibility.renderSecurityContext" (dict "secContext" .Values.defaultInitContainers.waitForRedis.containerSecurityContext "context" $) | nindent 4 }}
  {{- end }}
  command:
    - /bin/bash
  args:
    - -ec
    - |
        set -o errexit
        set -o nounset
        set -o pipefail

        . /opt/bitnami/scripts/libos.sh
        . /opt/bitnami/scripts/liblog.sh

        {{- if .Values.usePasswordFiles }}
        export REDIS_PASSWORD="$(< $REDIS_PASSWORD_FILE)"
        {{- end }}

        check_redis_connection() {
            local result="$(redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT_NUMBER} -a ${REDIS_PASSWORD} --user ${REDIS_USER} PING)"
            if [[ "$result" != "PONG" ]]; then
            false
            fi
        }

        info "Checking redis connection..."
        if ! retry_while "check_redis_connection"; then
            error "Could not connect to the Redis server"
            exit 1
        else
            info "Connected to the Redis instance"
        fi
  env:
    {{- include "hazel.configure.redis" . | nindent 4 }}
  {{- if .Values.usePasswordFiles }}
  volumeMounts:
    - name: hazel-secrets
      mountPath: /opt/bitnami/hazel/secrets
      readOnly: true
  {{- end }}
{{- end }}

{{- define "hazel.initContainers.waitForExamples" -}}
# NOTE: The value postgresql.image is not available unless postgresql.enabled is not set.
# We could change this to use hazel image postgresql client.
- name: wait-for-examples
  image: {{ include "common.images.image" (dict "imageRoot" .Values.postgresql.image "global" .Values.global) }}
  imagePullPolicy: {{ .Values.postgresql.image.pullPolicy  }}
  {{- if .Values.web.waitForExamples.resources }}
  resources: {{ toYaml .Values.web.waitForExamples.resources | nindent 4 }}
  {{- else if ne .Values.web.waitForExamples.resourcesPreset "none" }}
  resources: {{- include "common.resources.preset" (dict "type" .Values.web.waitForExamples.resourcesPreset) | nindent 4 }}
  {{- end }}
  {{- if .Values.web.waitForExamples.containerSecurityContext.enabled }}
  securityContext: {{- include "common.compatibility.renderSecurityContext" (dict "secContext" .Values.web.waitForExamples.containerSecurityContext "context" $) | nindent 4 }}
  {{- end }}
  command:
    - /bin/bash
  args:
    - -ec
    - |
        set -o errexit
        set -o nounset
        set -o pipefail

        . /opt/bitnami/scripts/libos.sh
        . /opt/bitnami/scripts/liblog.sh
        . /opt/bitnami/scripts/libpostgresql.sh

        {{- if .Values.usePasswordFiles }}
        export hazel_DATABASE_PASSWORD="$(< $hazel_DATABASE_PASSWORD_FILE)"
        {{- end }}

        check_examples_database() {
            # deck.gl Demo is one of the latest dashboards loaded.
            echo "SELECT dashboard_title FROM dashboards" | postgresql_remote_execute_print_output "$hazel_DATABASE_HOST" "$hazel_DATABASE_PORT_NUMBER" "$hazel_DATABASE_NAME" "$hazel_DATABASE_USER" "$hazel_DATABASE_PASSWORD" | grep "deck.gl Demo"
        }

        info "Checking if the 'examples' database exists at $hazel_DATABASE_HOST:$hazel_DATABASE_PORT_NUMBER"
        # Retry 5 min
        if ! retry_while "check_examples_database" 60; then
            error "Examples database not ready yet"
            exit 1
        else
            info "Connected to the PostgreSQL instance"
        fi
  env:
    {{- include "hazel.configure.database" . | nindent 4 }}
  {{- if .Values.usePasswordFiles }}
  volumeMounts:
    - name: hazel-secrets
      mountPath: /opt/bitnami/hazel/secrets
      readOnly: true
  {{- end }}
{{- end }}

{{/*
Compile all warnings into a single message.
*/}}
{{- define "hazel.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "hazel.validateValues.database" .) -}}
{{- $messages := append $messages (include "hazel.validateValues.redis" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message -}}
{{- end -}}
{{- end -}}

{{/* Validate values of hazel - Postgresql */}}
{{- define "hazel.validateValues.database" -}}
{{- if and .Values.postgresql.enabled .Values.externalDatabase.host -}}
hazel: Database
    You can only use one database.
    Please choose installing a Postgresql chart (--set postgresql.enabled=true) or
    using an external database (--set externalDatabase.host)
{{- end -}}
{{- if and (not .Values.postgresql.enabled) (not .Values.externalDatabase.host) -}}
hazel: NoDatabase
    You did not set any database.
    Please choose installing a Postgresql chart (--set postgresql.enabled=true) or
    using an external instance (--set externalDatabase.host)
{{- end -}}
{{- end -}}

{{/* Validate values of hazel - Redis */}}
{{- define "hazel.validateValues.redis" -}}
{{- if and .Values.redis.enabled .Values.externalRedis.host -}}
hazel: Redis
    You can only use one Redis.
    Please choose installing a Redis chart (--set redis.enabled=true) or
    using an external Redis (--set externalRedis.host)
{{- end -}}
{{- if and (not .Values.redis.enabled) (not .Values.externalRedis.host) -}}
hazel: NoRedis
    You did not set any Redis.
    Please choose installing a Redis chart (--set redis.enabled=true) or
    using an external instance (--set externalRedis.host)
{{- end -}}
{{- end -}}
