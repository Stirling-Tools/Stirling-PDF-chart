{{/*
Name for a bundled component, short enough for StatefulSet pod and revision labels (max 52 chars)
Usage: include "stirlingpdf.componentName" (list . "postgresql")
*/}}
{{- define "stirlingpdf.componentName" -}}
{{- $ctx := index . 0 -}}
{{- $suffix := index . 1 -}}
{{- $max := sub 51 (len $suffix) | int -}}
{{- printf "%s-%s" (include "stirlingpdf.fullname" $ctx | trunc $max | trimSuffix "-") $suffix -}}
{{- end }}

{{/*
Selector labels for a bundled component. The name differs from the app's so the app's
immutable Deployment selector never matches these pods.
*/}}
{{- define "stirlingpdf.componentSelectorLabels" -}}
{{- $ctx := index . 0 -}}
{{- $component := index . 1 -}}
app.kubernetes.io/name: {{ printf "%s-%s" (include "stirlingpdf.name" $ctx | trunc 40 | trimSuffix "-") $component }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{- define "stirlingpdf.componentLabels" -}}
{{- $ctx := index . 0 -}}
helm.sh/chart: {{ include "stirlingpdf.chart" $ctx }}
{{ include "stirlingpdf.componentSelectorLabels" . }}
app.kubernetes.io/part-of: {{ include "stirlingpdf.name" $ctx }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
{{- if $ctx.Values.commonLabels }}
{{ toYaml $ctx.Values.commonLabels }}
{{- end }}
{{- end }}

{{/* The Stirling-PDF image, also used by the app's init containers */}}
{{- define "stirlingpdf.image" -}}
{{- $ref := printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion | toString) -}}
{{- if .Values.image.sha }}{{ printf "%s@sha256:%s" $ref .Values.image.sha }}{{ else }}{{ $ref }}{{ end -}}
{{- end }}

{{/*
Image reference for a bundled component. Usage: include "stirlingpdf.componentImage" .Values.postgresql.image
*/}}
{{- define "stirlingpdf.componentImage" -}}
{{- if .registry -}}
{{- printf "%s/%s:%s" .registry .repository (toString .tag) -}}
{{- else -}}
{{- printf "%s:%s" .repository (toString .tag) -}}
{{- end -}}
{{- end }}

{{/*
The given value, else the one in the live Secret, else a new one, so secrets survive upgrades.
`helm template` cannot look up Secrets, so there it always generates.
*/}}
{{- define "stirlingpdf.stableSecretValue" -}}
{{- if .value -}}
{{- .value -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" .ctx.Release.Namespace .secret -}}
{{- if and $existing $existing.data (hasKey $existing.data .key) -}}
{{- index $existing.data .key | b64dec -}}
{{- else -}}
{{- .generate -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/* Which backing services are configured. Each returns "true" or an empty string. */}}
{{- define "stirlingpdf.db.enabled" -}}
{{- if or .Values.postgresql.enabled .Values.externalDatabase.host .Values.externalDatabase.jdbcUrl }}true{{ end -}}
{{- end }}

{{- define "stirlingpdf.valkey.enabled" -}}
{{- if or .Values.valkey.enabled .Values.externalValkey.host }}true{{ end -}}
{{- end }}

{{- define "stirlingpdf.s3.enabled" -}}
{{- if or .Values.s3.enabled .Values.externalS3.bucket }}true{{ end -}}
{{- end }}

{{- define "stirlingpdf.sharedKeys.enabled" -}}
{{- if or .Values.cluster.enabled (include "stirlingpdf.db.enabled" .) }}true{{ end -}}
{{- end }}

{{/* Secret names */}}
{{- define "stirlingpdf.appSecretName" -}}
{{- include "stirlingpdf.fullname" . -}}
{{- end }}

{{- define "stirlingpdf.sharedKeysSecretName" -}}
{{- .Values.sharedKeys.existingSecret | default (printf "%s-keys" (include "stirlingpdf.fullname" . | trunc 58 | trimSuffix "-")) -}}
{{- end }}

{{- define "stirlingpdf.postgresql.secretName" -}}
{{- .Values.postgresql.auth.existingSecret | default (include "stirlingpdf.componentName" (list . "postgresql")) -}}
{{- end }}

{{- define "stirlingpdf.valkey.secretName" -}}
{{- .Values.valkey.auth.existingSecret | default (include "stirlingpdf.componentName" (list . "valkey")) -}}
{{- end }}

{{- define "stirlingpdf.s3.secretName" -}}
{{- .Values.s3.auth.existingSecret | default (include "stirlingpdf.componentName" (list . "s3")) -}}
{{- end }}

{{/* True when the chart's app Secret holds at least one value */}}
{{- define "stirlingpdf.appSecret.enabled" -}}
{{- $v := .Values -}}
{{- if and $v.premium.enabled $v.premium.key (not $v.premium.existingSecret) }}true{{ end -}}
{{- if and (not $v.postgresql.enabled) $v.externalDatabase.password (not $v.externalDatabase.existingSecret) }}true{{ end -}}
{{- if and (not $v.valkey.enabled) $v.externalValkey.password (not $v.externalValkey.existingSecret) }}true{{ end -}}
{{- if and (not $v.s3.enabled) $v.externalS3.accessKey (not $v.externalS3.existingSecret) }}true{{ end -}}
{{- end }}

{{/* host:port pairs the app waits for before starting */}}
{{- define "stirlingpdf.dependencies" -}}
{{- $deps := list -}}
{{- if .Values.postgresql.enabled -}}
{{- $deps = append $deps (printf "%s:5432" (include "stirlingpdf.componentName" (list . "postgresql"))) -}}
{{- else if .Values.externalDatabase.host -}}
{{- $deps = append $deps (printf "%s:%v" .Values.externalDatabase.host .Values.externalDatabase.port) -}}
{{- end -}}
{{- if .Values.cluster.enabled -}}
{{- if .Values.valkey.enabled -}}
{{- $deps = append $deps (printf "%s:6379" (include "stirlingpdf.componentName" (list . "valkey"))) -}}
{{- else if .Values.externalValkey.host -}}
{{- $deps = append $deps (printf "%s:%v" .Values.externalValkey.host .Values.externalValkey.port) -}}
{{- end -}}
{{- end -}}
{{- if .Values.s3.enabled -}}
{{- $deps = append $deps (printf "%s:9000" (include "stirlingpdf.componentName" (list . "s3"))) -}}
{{- end -}}
{{- join " " $deps -}}
{{- end }}

{{/*
Environment the chart derives from the database, cluster, S3 and licence settings.
Rendered before `envs`, so a user entry with the same name wins.
*/}}
{{- define "stirlingpdf.generatedEnv" -}}
{{- $v := .Values -}}
{{- $app := include "stirlingpdf.appSecretName" . -}}
{{- if include "stirlingpdf.db.enabled" . }}
- name: SYSTEM_DATASOURCE_ENABLECUSTOMDATABASE
  value: "true"
{{- if $v.postgresql.enabled }}
- name: SYSTEM_DATASOURCE_TYPE
  value: postgresql
- name: SYSTEM_DATASOURCE_HOSTNAME
  value: {{ include "stirlingpdf.componentName" (list . "postgresql") | quote }}
- name: SYSTEM_DATASOURCE_PORT
  value: "5432"
- name: SYSTEM_DATASOURCE_NAME
  value: {{ $v.postgresql.auth.database | quote }}
- name: SYSTEM_DATASOURCE_USERNAME
  value: {{ $v.postgresql.auth.username | quote }}
- name: SYSTEM_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.postgresql.secretName" . }}
      key: {{ $v.postgresql.auth.secretKey }}
{{- else }}
{{- if $v.externalDatabase.jdbcUrl }}
- name: SYSTEM_DATASOURCE_CUSTOMDATABASEURL
  value: {{ $v.externalDatabase.jdbcUrl | quote }}
{{- else }}
- name: SYSTEM_DATASOURCE_TYPE
  value: postgresql
- name: SYSTEM_DATASOURCE_HOSTNAME
  value: {{ $v.externalDatabase.host | quote }}
- name: SYSTEM_DATASOURCE_PORT
  value: {{ $v.externalDatabase.port | quote }}
- name: SYSTEM_DATASOURCE_NAME
  value: {{ $v.externalDatabase.database | quote }}
{{- end }}
- name: SYSTEM_DATASOURCE_USERNAME
  value: {{ $v.externalDatabase.username | quote }}
{{- if or $v.externalDatabase.existingSecret $v.externalDatabase.password }}
- name: SYSTEM_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $v.externalDatabase.existingSecret | default $app }}
      key: {{ ternary $v.externalDatabase.existingSecretPasswordKey "database-password" (not (empty $v.externalDatabase.existingSecret)) }}
{{- end }}
{{- end }}
{{- end }}
{{- if include "stirlingpdf.sharedKeys.enabled" . }}
- name: STIRLING_CREDENTIAL_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.sharedKeysSecretName" . }}
      key: credential-encryption-key
- name: AUTOMATICALLYGENERATED_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.sharedKeysSecretName" . }}
      key: automatically-generated-key
- name: AUTOMATICALLYGENERATED_UUID
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.sharedKeysSecretName" . }}
      key: automatically-generated-uuid
{{- end }}
{{- if $v.premium.enabled }}
- name: PREMIUM_ENABLED
  value: "true"
{{- if or $v.premium.existingSecret $v.premium.key }}
- name: PREMIUM_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $v.premium.existingSecret | default $app }}
      key: {{ ternary $v.premium.existingSecretKey "premium-key" (not (empty $v.premium.existingSecret)) }}
{{- end }}
{{- end }}
{{- if include "stirlingpdf.s3.enabled" . }}
{{- if $v.premium.enabled }}
# Unlicensed, the app refuses to start with provider s3 even when file storage is off
- name: STORAGE_PROVIDER
  value: s3
{{- end }}
{{- if $v.s3.enabled }}
- name: STORAGE_S3_ENDPOINT
  value: {{ printf "http://%s:9000" (include "stirlingpdf.componentName" (list . "s3")) | quote }}
- name: STORAGE_S3_BUCKET
  value: {{ $v.s3.bucket | quote }}
- name: STORAGE_S3_REGION
  value: us-east-1
- name: STORAGE_S3_PATHSTYLEACCESS
  value: "true"
- name: STORAGE_S3_ALLOWPRIVATEENDPOINTS
  value: "true"
- name: STORAGE_S3_ACCESSKEY
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.s3.secretName" . }}
      key: root-user
- name: STORAGE_S3_SECRETKEY
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.s3.secretName" . }}
      key: root-password
{{- else }}
- name: STORAGE_S3_ENDPOINT
  value: {{ $v.externalS3.endpoint | quote }}
- name: STORAGE_S3_BUCKET
  value: {{ $v.externalS3.bucket | quote }}
- name: STORAGE_S3_REGION
  value: {{ $v.externalS3.region | quote }}
- name: STORAGE_S3_PATHSTYLEACCESS
  value: {{ $v.externalS3.pathStyleAccess | quote }}
- name: STORAGE_S3_ALLOWPRIVATEENDPOINTS
  value: {{ $v.externalS3.allowPrivateEndpoints | quote }}
{{- if or $v.externalS3.existingSecret $v.externalS3.accessKey }}
- name: STORAGE_S3_ACCESSKEY
  valueFrom:
    secretKeyRef:
      name: {{ $v.externalS3.existingSecret | default $app }}
      key: {{ ternary $v.externalS3.existingSecretAccessKeyKey "s3-access-key" (not (empty $v.externalS3.existingSecret)) }}
- name: STORAGE_S3_SECRETKEY
  valueFrom:
    secretKeyRef:
      name: {{ $v.externalS3.existingSecret | default $app }}
      key: {{ ternary $v.externalS3.existingSecretSecretKeyKey "s3-secret-key" (not (empty $v.externalS3.existingSecret)) }}
{{- end }}
{{- end }}
{{- end }}
{{- if $v.cluster.enabled }}
- name: CLUSTER_ENABLED
  value: "true"
- name: CLUSTER_BACKPLANE
  value: valkey
- name: CLUSTER_ARTIFACTSTORE
  value: s3
- name: CLUSTER_S3_KEYPREFIX
  value: {{ $v.cluster.artifactKeyPrefix | quote }}
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: CLUSTER_NODE_ID
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
{{- if $v.valkey.enabled }}
- name: CLUSTER_VALKEY_URL
  value: {{ printf "redis://%s:6379" (include "stirlingpdf.componentName" (list . "valkey")) | quote }}
{{- if $v.valkey.auth.enabled }}
- name: CLUSTER_VALKEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "stirlingpdf.valkey.secretName" . }}
      key: {{ $v.valkey.auth.secretKey }}
{{- end }}
{{- else }}
- name: CLUSTER_VALKEY_URL
  value: {{ printf "%s://%s:%v/%v" (ternary "rediss" "redis" $v.externalValkey.tls) $v.externalValkey.host $v.externalValkey.port $v.externalValkey.database | quote }}
{{- if $v.externalValkey.username }}
- name: CLUSTER_VALKEY_USERNAME
  value: {{ $v.externalValkey.username | quote }}
{{- end }}
{{- if or $v.externalValkey.existingSecret $v.externalValkey.password }}
- name: CLUSTER_VALKEY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $v.externalValkey.existingSecret | default $app }}
      key: {{ ternary $v.externalValkey.existingSecretPasswordKey "valkey-password" (not (empty $v.externalValkey.existingSecret)) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
"true" when the app container runs as a non-root user. The 3.0.0 image links helper scripts into
/usr/local/bin at startup, which only root can write, so the chart gives that path a writable copy.
*/}}
{{- define "stirlingpdf.nonRoot" -}}
{{- $pod := ternary .Values.securityContext dict (and (kindIs "map" .Values.securityContext) (.Values.securityContext.enabled | default false)) -}}
{{- $ctr := .Values.containerSecurityContext | default dict -}}
{{- $uid := $ctr.runAsUser | default $pod.runAsUser -}}
{{- if or $ctr.runAsNonRoot $pod.runAsNonRoot (and $uid (ne (int $uid) 0)) }}true{{ end -}}
{{- end }}
