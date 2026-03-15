{{- define "hazel.ingressroute.tlscertificate" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $existingTlsSecretName := index $root.Values.hazel $component "existingTlsSecretName" -}}
{{- $host := index $root.Values.hazel $component "host" -}}
{{- $generatedTlsSecretName := $host | replace "." "-" }}
{{- $tlsIssuerName := index $root.Values.hazel $component "tlsIssuerName" -}}
{{- $tlsIssuerKind := index $root.Values.hazel $component "tlsIssuerKind" -}}
{{- if not $existingTlsSecretName }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ $generatedTlsSecretName | quote }}
spec:
  secretName: {{ $generatedTlsSecretName | quote }}
  issuerRef:
    name: {{ $tlsIssuerName | quote }}
    {{- if $tlsIssuerKind }}
    kind: {{ $tlsIssuerKind | quote }}
    {{- end }}
  dnsNames:
    - {{ $host | quote }}
{{- end }}
{{- end -}}

{{- define "hazel.ingressroute.tlsname" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $existingTlsSecretName := index $root.Values.hazel $component "existingTlsSecretName" -}}
{{- $host := index $root.Values.hazel $component "host" -}}
{{- $generatedTlsSecretName := $host | replace "." "-" }}
{{- if $existingTlsSecretName }}
secretName: {{ $existingTlsSecretName | quote }}
{{- else }}
secretName: {{ $generatedTlsSecretName | quote }}
{{- end }}
{{- end -}}

{{/*
  Template: hazel.ingressroute.integratedtls
  Usage: {{ include "hazel.ingressroute.integratedtls" (dict "component" "cms" "root" .) }}
  Renders the tls object for an IngressRoute, using existingTlsSecretName if set, otherwise certResolver.
  TODO: remove if not needed
*/}}
{{- define "hazel.ingressroute.integratedtls" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $existingTlsSecretName := index $root.Values.hazel $component "existingTlsSecretName" -}}
{{- $certResolver := $root.Values.hazel.traefik.certResolver -}}
{{- if $existingTlsSecretName }}
secretName: {{ $existingTlsSecretName | quote }}
{{- else }}
certResolver: {{ $certResolver | quote }}
{{- end }}
{{- end -}}

{{/*
  InitContainer to wait for Argo Workflow completion using curl
  Usage: {{ include "hazel.waitForArgoWorkflowInitContainer" (dict "namespace" .Values.global.namespace) }}
  TODO: remove if not needed
*/}}
{{- define "hazel.waitForArgoWorkflowInitContainer" -}}
- name: wait-for-migrations
  image: nixery.dev/shell/curl/jq
  imagePullPolicy: IfNotPresent
  command:
    - /bin/sh
    - -c
    - |
      # This init container waits for an Argo Workflow to complete. It supports two modes:
      # 1) If WORKFLOW_NAME is provided (environment variable override), wait for that workflow.
      # 2) Otherwise, wait for the latest Workflow created from the WorkflowTemplate
      #    named WORKFLOW_TEMPLATE_NAME (default: hazel-init-workflow-template).
      TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      NAMESPACE={{ .namespace }}
      # Optional overrides: you can set WORKFLOW_NAME or WORKFLOW_TEMPLATE_NAME via env when using the helper
      WORKFLOW_NAME=${WORKFLOW_NAME:-}
      WORKFLOW_TEMPLATE_NAME=${WORKFLOW_TEMPLATE_NAME:-hazel-init-workflow-template}
      API_SERVER=https://kubernetes.default.svc

      echo "Waiting for Argo Workflow (template='$WORKFLOW_TEMPLATE_NAME', name='$WORKFLOW_NAME') in namespace $NAMESPACE"
      echo "Using jq version: $(jq --version)"

      while true; do
        if [ -z "$WORKFLOW_NAME" ]; then
          # Find the most recent Workflow created from the WorkflowTemplate
          echo "$(curl -s --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "$API_SERVER/apis/argoproj.io/v1alpha1/namespaces/$NAMESPACE/workflows")"
          echo "--------------------------------"
          WORKFLOW_NAME=$(curl -s --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" \
            "$API_SERVER/apis/argoproj.io/v1alpha1/namespaces/$NAMESPACE/workflows" \
            | jq -r --arg tpl "$WORKFLOW_TEMPLATE_NAME" '.items[] | select(.spec.workflowTemplateRef.name == $tpl) | .metadata.name' \
            | sort | tail -n 1)
          if [ -z "$WORKFLOW_NAME" ]; then
            echo "No workflow found for template '$WORKFLOW_TEMPLATE_NAME' yet. Waiting..."
            sleep 5
            continue
          fi
          echo "Found workflow $WORKFLOW_NAME for template $WORKFLOW_TEMPLATE_NAME"
        fi

        status=$(curl -s --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" \
          "$API_SERVER/apis/argoproj.io/v1alpha1/namespaces/$NAMESPACE/workflows/$WORKFLOW_NAME" \
          | jq -r '.status.phase' 2>/dev/null)

        if [ "$status" = "Succeeded" ]; then
          echo "Argo Workflow '$WORKFLOW_NAME' completed successfully."
          break
        elif [ "$status" = "Failed" ] || [ "$status" = "Error" ]; then
          echo "Argo Workflow '$WORKFLOW_NAME' failed or errored. Exiting."
          exit 1
        elif [ -z "$status" ] || [ "$status" = "null" ]; then
          echo "Workflow $WORKFLOW_NAME not found or no status yet. Resetting name and waiting..."
          WORKFLOW_NAME=
          sleep 5
          continue
        fi

        echo "Workflow status: $status. Waiting..."
        sleep 10
      done
{{- end }}
{{/*
Expand the name of the chart.
*/}}
{{- define "hazel.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hazel.fullname" -}}
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
{{- define "hazel.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hazel.labels" -}}
helm.sh/chart: {{ include "hazel.chart" . }}
app.kubernetes.io/name: {{ include "hazel.name" . }}
app.kubernetes.io/instance: hazel-{{ .Values.global.instanceId }}
app.kubernetes.io/version: {{ .Values.global.hazelVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: hazel
{{- with .Values.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hazel.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hazel.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "hazel.componentLabels" -}}
{{- $component := .component }}
{{- include "hazel.labels" .root | nindent 0 }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Component-specific selector labels
*/}}
{{- define "hazel.componentSelectorLabels" -}}
{{- $component := .component }}
app.kubernetes.io/name: {{ include "hazel.name" .root }}
app.kubernetes.io/instance: hazel-{{ .root.Values.global.instanceId }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Common annotations that match Kustomize commonAnnotations
*/}}
{{- define "hazel.annotations" -}}
app.kubernetes.io/version: {{ .Values.global.hazelVersion | quote }}
{{- with .Values.commonAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "hazel.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hazel.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate image reference
*/}}
{{- define "hazel.image" -}}
{{- $comp := .component -}}
{{- if eq $comp "hazel" -}}
  {{- $img := .root.Values.hazel.image -}}
  {{- printf "%s:%s" $img.repository $img.tag -}}
{{- else if hasKey .root.Values.hazel $comp -}}
  {{- $img := (index .root.Values.hazel $comp).image -}}
  {{- printf "%s:%s" $img.repository $img.tag -}}
{{- else -}}
  {{- printf "" -}}
{{- end -}}
{{- end }}

{{/*
Pull policy for images
*/}}
{{- define "hazel.imagePullPolicy" -}}
{{- $comp := .component -}}
{{- if eq $comp "hazel" -}}
  {{- .root.Values.hazel.image.pullPolicy | default "IfNotPresent" -}}
{{- else if hasKey .root.Values.hazel $comp -}}
  {{- ((index .root.Values.hazel $comp).image.pullPolicy) | default "IfNotPresent" -}}
{{- else -}}
  {{- printf "IfNotPresent" -}}
{{- end -}}
{{- end }}

{{/*
Shared environment variables
*/}}
{{- define "hazel.common.env" -}}
# Shared settings
- name: LMS_HOST
  value: {{ .Values.hazel.lms.host | quote }}
- name: PREVIEW_HOST
  value: {{ .Values.hazel.preview.host | quote }}
- name: CMS_HOST
  value: {{ .Values.hazel.cms.host | quote }}
- name: MFE_HOST
  value: {{ .Values.hazel.mfe.host | quote }}
- name: NOTES_HOST
  value: {{ .Values.hazel.notes.host | quote }}
- name: NOTES_SERVICE_HOST
  value: {{ .Values.hazel.notes.service.name | quote }}
- name: NOTES_SERVICE_PORT
  value: {{ .Values.hazel.notes.service.port | quote }}
- name: PLATFORM_NAME
  value: {{ .Values.hazel.platformName | quote }}
- name: CONTACT_EMAIL
  value: {{ .Values.hazel.contactEmail | quote }}

- name: KV_ENGINE
  value: {{ .Values.hazel.cache.backend.engine | quote }}
- name: KV_HOST
  value: {{ .Values.hazel.cache.backend.host | quote }}
- name: KV_PORT
  value: {{ .Values.hazel.cache.backend.port | quote }}
- name: KV_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.cache.backend.credentials }}
      key: username
- name: KV_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.cache.backend.credentials }}
      key: password
- name: HAZEL_CACHE_KV_DB
  value: {{ .Values.hazel.cache.backend.db | quote }}

- name: SMTP_USE_SSL
  value: {{ .Values.hazel.smtp.useSSL | quote }}

- name: JWT_RSA_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.jwtRsaPrivateKey.secretName }}
      key: {{ .Values.hazel.jwtRsaPrivateKey.secretKey }}
- name: JWT_COMMON_ISSUER
  value: "https://{{ .Values.hazel.lms.host }}/oauth2"
- name: JWT_COMMON_AUDIENCE
  value: {{ .Values.hazel.jwtCommonAudience | quote }}
- name: JWT_COMMON_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.jwtCommonSecretKey.secretName }}
      key: {{ .Values.hazel.jwtCommonSecretKey.secretKey }}
- name: HAZEL_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hazel.secretKey.secretName }}
      key: {{ .Values.hazel.secretKey.secretKey }}

- name: S3_GRADE_BUCKET
  value: {{ .Values.hazel.s3.gradeBucket | quote }}
- name: S3_PROFILE_IMAGE_BUCKET
  value: {{ .Values.hazel.s3.profileImageBucket | quote }}
- name: S3_STORAGE_BUCKET
  value: {{ .Values.hazel.s3.storageBucket | quote }}
- name: S3_FILE_UPLOAD_BUCKET
  value: {{ .Values.hazel.s3.fileUploadBucket | quote }}

# FIXME: what are these? Do we need them?
- name: S3_CUSTOM_DOMAIN
  value: {{ .Values.hazel.s3.s3CustomDomain | quote }}
- name: S3_PROFILE_IMAGE_CUSTOM_DOMAIN
  value: {{ .Values.hazel.s3.s3ProfileImageCustomDomain | quote }}

- name: S3_SIGNATURE_VERSION
  value: {{ .Values.hazel.s3.signatureVersion | quote }}
- name: S3_REQUEST_CHECKSUM_CALCULATION
  value: {{ .Values.hazel.s3.requestChecksumCalculation | quote }}
- name: S3_HOST
  value: {{ .Values.hazel.s3.host | quote }}
- name: S3_PORT
  value: {{ .Values.hazel.s3.port | quote }}
- name: S3_USE_SSL
  value: {{ .Values.hazel.s3.useSSL | quote }}
- name: S3_DEFAULT_ACL
  value: {{ .Values.hazel.s3.defaultACL | quote }}
- name: S3_ADDRESSING_STYLE
  value: {{ .Values.hazel.s3.addressingStyle | quote }}
- name: S3_REGION
  value: {{ .Values.hazel.s3.region | quote }}

{{- end }}

{{/*
Shared dev volume mounts
*/}}
{{- define "hazel.dev.volumeMounts" -}}
{{- if and .Values.hazel.isDev .Values.hazel.local.src }}
- name: edx-platform
  mountPath: /hazel/edx-platform
- name: mnt
  mountPath: /mnt
{{- end }}
{{- end -}}

{{/*
Shared dev volumes
*/}}
{{- define "hazel.dev.volumes" -}}
{{- if and .Values.hazel.isDev .Values.hazel.local.src }}
- name: edx-platform
  hostPath:
    path: /hazel/edx-platform
- name: mnt
  hostPath:
    path: /mnt
{{- end }}
{{- end -}}

{{/*
CA trust init container for development with component parameter
Usage: {{ include "hazel.dev.caInitContainerForComponent" (dict "component" "mfe" "root" .) }}
Uses the specified component's image to ensure cert compatibility
*/}}
{{- define "hazel.dev.caInitContainerForComponent" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- if $root.Values.hazel.isDev }}
- name: install-custom-ca
  image: {{ include "hazel.image" (dict "component" $component "root" $root) }}
  imagePullPolicy: {{ include "hazel.imagePullPolicy" (dict "component" $component "root" $root) }}
  securityContext:
    runAsUser: 0
  command:
  - sh
  - -c
  - |
    # Copy system certs from the image to our emptyDir volumes
    cp -r /etc/ssl/certs/* /shared-etc-ssl-certs/ 2>/dev/null || true
    cp -r /usr/local/share/ca-certificates/* /shared-usr-local-ca-certs/ 2>/dev/null || true

    # Add our custom CA
    cp /tmp/ca-bundle/ca-bundle.crt /shared-usr-local-ca-certs/mkcert-ca.crt

    # Run update-ca-certificates with the shared directories
    # We need to temporarily mount them in the standard locations
    rm -rf /etc/ssl/certs/*
    rm -rf /usr/local/share/ca-certificates/*
    cp -r /shared-etc-ssl-certs/* /etc/ssl/certs/
    cp -r /shared-usr-local-ca-certs/* /usr/local/share/ca-certificates/

    update-ca-certificates

    # Copy back the updated certs to shared volumes
    cp -r /etc/ssl/certs/* /shared-etc-ssl-certs/
    cp -r /usr/local/share/ca-certificates/* /shared-usr-local-ca-certs/

    # Ensure readable by all users
    chmod -R 755 /shared-etc-ssl-certs
    chmod -R 755 /shared-usr-local-ca-certs
    echo "Custom CA installed successfully"
  volumeMounts:
  - name: ca-bundle
    mountPath: /tmp/ca-bundle
    readOnly: true
  - name: usr-local-share-ca-certs
    mountPath: /shared-usr-local-ca-certs
  - name: etc-ssl-certs
    mountPath: /shared-etc-ssl-certs
{{- end }}
{{- end -}}

{{/*
CA trust volume mounts for development
*/}}
{{- define "hazel.dev.caVolumeMounts" -}}
{{- if .Values.hazel.isDev }}
- name: usr-local-share-ca-certs
  mountPath: /usr/local/share/ca-certificates
- name: etc-ssl-certs
  mountPath: /etc/ssl/certs
{{- end }}
{{- end -}}

{{/*
CA trust init container for MinIO mc (Alpine-based)
mc uses ${MC_CONFIG_DIR}/certs/CAs/ for custom CA certificates
*/}}
{{- define "hazel.dev.mcCaInitContainer" -}}
{{- if .Values.hazel.isDev }}
- name: install-custom-ca
  image: alpine:latest
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
    allowPrivilegeEscalation: false
  command:
  - sh
  - -c
  - |
    # Create the mc CAs directory
    mkdir -p /mc-config/certs/CAs

    # Copy the custom CA certificate
    cp /tmp/ca-bundle/ca-bundle.crt /mc-config/certs/CAs/mkcert-ca.crt

    echo "Custom CA installed successfully in /mc-config/certs/CAs/"
  volumeMounts:
  - name: ca-bundle
    mountPath: /tmp/ca-bundle
    readOnly: true
  - name: mc-config
    mountPath: /mc-config
{{- end }}
{{- end -}}

{{/*
CA trust volumes for development
*/}}
{{- define "hazel.dev.caVolumes" -}}
{{- if .Values.hazel.isDev }}
- name: ca-bundle
  configMap:
    name: mkcert-trust-bundle
- name: usr-local-share-ca-certs
  emptyDir: {}
- name: etc-ssl-certs
  emptyDir: {}
{{- end }}
{{- end -}}

{{/*
Shared common volume mounts
*/}}
{{- define "hazel.common.volumeMounts" -}}
- name: config
  mountPath: /hazel/config
  readOnly: true
- name: settings-cms
  mountPath: /hazel/edx-platform/cms/envs/tutor/
- name: settings-lms
  mountPath: /hazel/edx-platform/lms/envs/tutor/
{{- end -}}

{{/*
Shared common volumes
*/}}
{{- define "hazel.common.volumes" -}}
- name: config
  secret:
    secretName: hazel-config
- name: settings-cms
  configMap:
    name: hazel-settings-cms
- name: settings-lms
  configMap:
    name: hazel-settings-lms
{{- end -}}

{{- define "hazel.imagePullSecrets" -}}
# FIXME: fill this with real values!!!
{{ include "common.images.pullSecrets" (dict "images" (list  .Values.hazel.something.image .Values.hazel.somethingelse.image) "global" .Values.global) }}
{{- end -}}
