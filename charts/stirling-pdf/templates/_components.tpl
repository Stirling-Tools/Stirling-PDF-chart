{{/* The Stirling-PDF image, also used by the app's init containers */}}
{{- define "stirlingpdf.image" -}}
{{- $ref := printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion | toString) -}}
{{- if .Values.image.sha }}{{ printf "%s@sha256:%s" $ref .Values.image.sha }}{{ else }}{{ $ref }}{{ end -}}
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
{{- if or .Values.externalDatabase.host .Values.externalDatabase.jdbcUrl }}true{{ end -}}
{{- end }}

{{- define "stirlingpdf.valkey.enabled" -}}
{{- if .Values.externalValkey.host }}true{{ end -}}
{{- end }}

{{- define "stirlingpdf.s3.enabled" -}}
{{- if .Values.externalS3.bucket }}true{{ end -}}
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

{{/* True when the chart's app Secret holds at least one value */}}
{{- define "stirlingpdf.appSecret.enabled" -}}
{{- $v := .Values -}}
{{- if and $v.premium.enabled $v.premium.key (not $v.premium.existingSecret) }}true{{ end -}}
{{- if and $v.externalDatabase.password (not $v.externalDatabase.existingSecret) }}true{{ end -}}
{{- if and $v.externalValkey.password (not $v.externalValkey.existingSecret) }}true{{ end -}}
{{- if and $v.externalS3.accessKey (not $v.externalS3.existingSecret) }}true{{ end -}}
{{- end }}

{{/* host:port pairs the app waits for before starting */}}
{{- define "stirlingpdf.dependencies" -}}
{{- $deps := list -}}
{{- if .Values.externalDatabase.host -}}
{{- $deps = append $deps (printf "%s:%v" .Values.externalDatabase.host .Values.externalDatabase.port) -}}
{{- end -}}
{{- if .Values.cluster.enabled -}}
{{- if .Values.externalValkey.host -}}
{{- $deps = append $deps (printf "%s:%v" .Values.externalValkey.host .Values.externalValkey.port) -}}
{{- end -}}
{{- end -}}
{{- join " " $deps -}}
{{- end }}

{{/*
Environment the chart derives from the database, cluster, S3 and licence settings.
A user `envs` entry with the same name replaces the generated one.
*/}}
{{- define "stirlingpdf.generatedEnv" -}}
{{- $v := .Values -}}
{{- $app := include "stirlingpdf.appSecretName" . -}}
{{- if $v.persistence.enabled }}
- name: STORAGE_LOCAL_BASEPATH
  value: {{ printf "%s/storage" $v.persistence.path | quote }}
{{- end }}
{{- if include "stirlingpdf.db.enabled" . }}
- name: SYSTEM_DATASOURCE_ENABLECUSTOMDATABASE
  value: "true"
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

{{/*
"true" when the app container runs as a non-root user. The 3.x image links helper scripts into
/usr/local/bin at startup, which only root can write, so the chart gives that path a writable copy.
*/}}
{{- define "stirlingpdf.nonRoot" -}}
{{- $pod := ternary .Values.securityContext dict (and (kindIs "map" .Values.securityContext) (.Values.securityContext.enabled | default false)) -}}
{{- $ctr := .Values.containerSecurityContext | default dict -}}
{{- $uid := $ctr.runAsUser | default $pod.runAsUser -}}
{{- if or .Values.deployment.arbitraryUid $ctr.runAsNonRoot $pod.runAsNonRoot (and $uid (ne (int $uid) 0)) }}true{{ end -}}
{{- end }}
