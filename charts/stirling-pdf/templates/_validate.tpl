{{/*
Fails rendering on value combinations that cannot work, with a message saying what to change.
*/}}
{{- define "stirlingpdf.validate" -}}
{{- $v := .Values -}}
{{- $multi := or (gt (int $v.replicaCount) 1) (and $v.autoscaling.enabled (gt (int $v.autoscaling.maxReplicas) 1)) -}}
{{- if and $multi (not $v.cluster.enabled) -}}
{{- fail "replicaCount > 1 (or autoscaling) needs cluster.enabled=true. Several pods without cluster mode each keep their own database, logins and jobs. Set cluster.enabled=true with PostgreSQL, Valkey and S3, or use replicaCount: 1." -}}
{{- end -}}
{{- if and $v.autoscaling.enabled (not $v.cluster.enabled) -}}
{{- fail "autoscaling.enabled=true needs cluster.enabled=true." -}}
{{- end -}}
{{- $minPods := ternary (int $v.autoscaling.minReplicas) (int $v.replicaCount) (and $v.autoscaling.enabled true) -}}
{{- if and $v.podDisruptionBudget.enabled (le $minPods 1) (not (hasKey $v.podDisruptionBudget "maxUnavailable")) -}}
{{- fail "podDisruptionBudget.enabled=true with minAvailable and only one pod (replicaCount, or autoscaling.minReplicas) blocks node drains. Run 2 or more pods, or set podDisruptionBudget.maxUnavailable." -}}
{{- end -}}
{{- if $v.autoscaling.enabled -}}
{{- $requests := (($v.resources | default dict).requests | default dict) -}}
{{- if and $v.autoscaling.targetCPUUtilizationPercentage (not $requests.cpu) -}}
{{- fail "autoscaling.targetCPUUtilizationPercentage needs resources.requests.cpu, or the HPA cannot measure CPU use and never scales." -}}
{{- end -}}
{{- if and $v.autoscaling.targetMemoryUtilizationPercentage (not $requests.memory) -}}
{{- fail "autoscaling.targetMemoryUtilizationPercentage needs resources.requests.memory, or the HPA cannot measure memory use and never scales." -}}
{{- end -}}
{{- end -}}
{{- if and $v.httpRoute.enabled (not $v.httpRoute.parentRefs) -}}
{{- fail "httpRoute.enabled=true needs httpRoute.parentRefs (the Gateway the route attaches to)." -}}
{{- end -}}
{{- if and (include "stirlingpdf.valkey.enabled" .) (not $v.cluster.enabled) -}}
{{- fail "Valkey is only used in cluster mode. Set cluster.enabled=true, or unset externalValkey.host." -}}
{{- end -}}
{{- if $v.cluster.enabled -}}
{{- if not (include "stirlingpdf.db.enabled" .) -}}
{{- fail "cluster.enabled=true needs a shared PostgreSQL database: set externalDatabase.host or externalDatabase.jdbcUrl." -}}
{{- end -}}
{{- if not (include "stirlingpdf.valkey.enabled" .) -}}
{{- fail "cluster.enabled=true needs Valkey (or Redis): set externalValkey.host." -}}
{{- end -}}
{{- if not (include "stirlingpdf.s3.enabled" .) -}}
{{- fail "cluster.enabled=true needs S3 storage for job files: set externalS3.bucket." -}}
{{- end -}}
{{- if not $v.premium.enabled -}}
{{- fail "cluster.enabled=true needs a Server or Enterprise licence, or the app refuses to start. Set premium.enabled=true with premium.key or premium.existingSecret." -}}
{{- end -}}
{{- end -}}
{{- $userKey := false -}}
{{- range $v.envs -}}{{- if eq .name "PREMIUM_KEY" -}}{{- $userKey = true -}}{{- end -}}{{- end -}}
{{- if and $v.premium.enabled (not (or $v.premium.key $v.premium.existingSecret $userKey $v.envsFrom)) -}}
{{- fail "premium.enabled=true needs premium.key or premium.existingSecret (or PREMIUM_KEY supplied through envsFrom)." -}}
{{- end -}}
{{- if and $v.persistence.enabled (or $multi $v.cluster.enabled) (ne $v.persistence.accessMode "ReadWriteMany") (not $v.persistence.existingClaim) -}}
{{- fail "persistence.enabled=true with more than one pod needs persistence.accessMode=ReadWriteMany, because pods cannot share a ReadWriteOnce volume. In cluster mode the state lives in PostgreSQL and S3, so you can also set persistence.enabled=false." -}}
{{- end -}}
{{- if and $v.sharedKeys.credentialEncryptionKey (ne (len ($v.sharedKeys.credentialEncryptionKey | b64dec)) 32) -}}
{{- fail "sharedKeys.credentialEncryptionKey must be base64 of exactly 32 bytes. Generate one with: openssl rand -base64 32" -}}
{{- end -}}
{{- if not (hasPrefix "/" (toString $v.rootPath)) -}}
{{- fail "rootPath must start with '/', for example / or /stirling" -}}
{{- end -}}
{{- end }}

{{/*
Fails when values lack settings this chart version added. `helm upgrade --reuse-values` from an
older version causes this, because it skips the new chart's defaults.
*/}}
{{- define "stirlingpdf.checkValues" -}}
{{- $missing := list -}}
{{- range $k := list "cluster" "premium" "sharedKeys" "externalDatabase" "externalValkey" "externalS3" "autoscaling" "podDisruptionBudget" "waitForDependencies" -}}
{{- if not (hasKey $.Values $k) }}{{ $missing = append $missing $k }}{{ end -}}
{{- end -}}
{{- if not (hasKey (.Values.probes | default dict) "startup") }}{{ $missing = append $missing "probes.startup" }}{{ end -}}
{{- if $missing -}}
{{- fail (printf "These values are missing: %s. This happens with `helm upgrade --reuse-values` from an older chart version, which does not load the new chart's defaults. Upgrade with `--reset-then-reuse-values` (Helm 3.14+) or pass your own values file with -f instead." (join ", " $missing)) -}}
{{- end -}}
{{- end }}
