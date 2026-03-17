{{/*
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "hazel.imagePullSecrets" -}}
{{- $appConfigs := default (dict) .Values.apps.config -}}
{{- $images := list -}}
{{- range $appKey, $appConfig := $appConfigs -}}
{{- if and $appConfig (hasKey $appConfig "image") -}}
{{- $images = append $images $appConfig.image -}}
{{- end -}}
{{- end -}}
{{- include "common.images.renderPullSecrets" (dict "images" $images "context" $) -}}
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

{{/*
Normalize an app key to a DNS/label-safe token.
*/}}
{{- define "hazel.app.key" -}}
{{- $appKey := .appKey | toString | lower -}}
{{- $appKey = regexReplaceAll "[^a-z0-9-]" $appKey "-" -}}
{{- $appKey = trimAll "-" $appKey -}}
{{- if eq $appKey "" -}}
{{- fail "apps: app key resolves to empty after normalization" -}}
{{- end -}}
{{- $appKey -}}
{{- end -}}

{{/*
Get app keys for a specific generic resource kind.
Input: dict "root" $ "kind" "deployment|service|hpa|networkPolicy|pdb|vpa"
Output: YAML list
*/}}
{{- define "hazel.app.keysFor" -}}
{{- $root := .root -}}
{{- $kind := .kind -}}
{{- $apps := default (dict) $root.Values.apps -}}
{{- $generic := default (dict) $apps.generic -}}
{{- $config := default (dict) $apps.config -}}
{{- $validation := default (dict) $apps.validation -}}
{{- $keys := default (list) (index $generic $kind) -}}
{{- if (default false $validation.failOnUnknownAppInGenericLists) -}}
{{- range $appKey := $keys -}}
{{- if not (hasKey $config $appKey) -}}
{{- fail (printf "apps.generic.%s contains unknown app key %q (missing apps.config.%s)" $kind $appKey $appKey) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $keys -}}
{{- end -}}

{{/*
Get merged app config (defaults + apps.config.<key>, with app config taking precedence).
Input: dict "root" $ "appKey" "web"
Output: YAML map
*/}}
{{- define "hazel.app.config" -}}
{{- $root := .root -}}
{{- $appKey := .appKey -}}
{{- $apps := default (dict) $root.Values.apps -}}
{{- $defaults := default (dict) $apps.defaults -}}
{{- $config := default (dict) $apps.config -}}
{{- $validation := default (dict) $apps.validation -}}
{{- if and (default false $validation.failOnMissingAppConfig) (not (hasKey $config $appKey)) -}}
{{- fail (printf "missing required apps.config.%s" $appKey) -}}
{{- end -}}
{{- $appConfig := default (dict) (index $config $appKey) -}}
{{- $merged := mergeOverwrite (deepCopy $defaults) $appConfig -}}
{{- if and (default false $root.Values.hazel.isDev) (hasKey $appConfig "dev") -}}
{{- $merged = mergeOverwrite (deepCopy $merged) (default (dict) $appConfig.dev) -}}
{{- end -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
Return whether app is enabled using merged app config.
Input: dict "root" $ "appKey" "web"
Output: true|false
*/}}
{{- define "hazel.app.enabled" -}}
{{- $appConfig := include "hazel.app.config" . | fromYaml -}}
{{- if (default true $appConfig.enabled) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Create app-specific fullname.
Input: dict "root" $ "appKey" "web"
*/}}
{{- define "hazel.app.fullname" -}}
{{- $root := .root -}}
{{- $appKey := include "hazel.app.key" (dict "appKey" .appKey) -}}
{{- printf "%s-%s" (include "common.names.fullname" $root) $appKey | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create app component label value.
Input: dict "appKey" "web"
*/}}
{{- define "hazel.app.component" -}}
{{- $appKey := include "hazel.app.key" (dict "appKey" .appKey) -}}
{{- printf "hazel-%s" $appKey | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return app image from merged app config.
Input: dict "root" $ "appConfig" <map>
*/}}
{{- define "hazel.app.image" -}}
{{- $root := .root -}}
{{- $appConfig := default (dict) .appConfig -}}
{{- if not (hasKey $appConfig "image") -}}
{{- fail "app config must include image" -}}
{{- end -}}
{{- include "common.images.image" (dict "imageRoot" $appConfig.image "global" $root.Values.global) -}}
{{- end -}}
