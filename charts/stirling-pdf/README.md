# stirling-pdf-chart

![Version: 4.0.0](https://img.shields.io/badge/Version-4.0.0-informational?style=flat-square) ![AppVersion: 3.2.0](https://img.shields.io/badge/AppVersion-3.2.0-informational?style=flat-square)

locally hosted web application that allows you to perform various operations on PDF files

**Homepage:** <https://github.com/Stirling-Tools/Stirling-PDF>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Stirling-Tools |  | <https://github.com/Stirling-Tools/Stirling-PDF-chart> |

## Source Code

* <https://github.com/Stirling-Tools/Stirling-PDF-chart>

## Chart Repo

### Helm repository

Add the following repo to use the chart:

```console
helm repo add stirling-pdf https://docs.stirlingpdf.com/Stirling-PDF-chart
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling | object | `{"enabled":false,"maxReplicas":4,"minReplicas":2,"targetCPUUtilizationPercentage":80}` | HorizontalPodAutoscaler for the Stirling-PDF pods. Needs `cluster.enabled: true` and a metrics server. |
| cluster | object | `{"artifactKeyPrefix":"transient/","enabled":false,"stickySessions":true}` | Run Stirling-PDF as a multi-node cluster. Needs your own PostgreSQL, Valkey and S3 (`external*`) plus a licence (`premium`); the chart wires the app's cluster settings from them. |
| cluster.artifactKeyPrefix | string | `"transient/"` | Prefix for transient job files in the S3 bucket, so the bucket can also hold stored files |
| cluster.stickySessions | bool | `true` | Add sticky-cookie annotations for Traefik (on the Service) and ingress-nginx (on the Ingress). Async job results are only served by the pod that ran the job; other pods answer 410. |
| commonLabels | object | `{}` | Labels to apply to all resources |
| containerSecurityContext | object | `{}` | Container-level securityContext for the Stirling-PDF container |
| deployment.annotations | object | `{}` | Stirling-pdf Deployment annotations |
| deployment.arbitraryUid | bool | `false` | Set to true when the pod runs as a user id the image does not know, for example OpenShift's random UIDs. Adds a passwd entry for that id and writable copies of the image's data directories. |
| deployment.extraVolumeMounts | list | `[]` | Additional volumes to mount |
| deployment.extraVolumes | list | `[]` | Additional volumes |
| deployment.initContainers | list | `[]` | Extra init containers, run after the chart's own init containers |
| deployment.labels | object | `{}` |  |
| deployment.preStopSleepSeconds | int | `10` | Seconds a terminating pod keeps receiving no new traffic before the app is stopped. Gives Services and ingress controllers time to drop the pod, so rolling updates do not fail requests. |
| deployment.sidecarContainers | object | `{}` | of the chart's content, send notifications... |
| deployment.terminationGracePeriodSeconds | int | `60` | Time allowed for a graceful shutdown (preStop sleep plus the app draining in-flight requests) |
| envs | list | `[]` | Environment variables to add to the stirling-pdf pods. These are applied after the variables the chart generates, so an entry here overrides a chart-generated one of the same name. |
| envsFrom | list | `[]` | Environment variables from secrets or configmaps to add to the stirling-pdf pods |
| externalDatabase | object | `{"database":"stirling","existingSecret":"","existingSecretPasswordKey":"password","host":"","jdbcUrl":"","password":"","port":5432,"username":"stirling"}` | Your PostgreSQL server, used when `host` or `jdbcUrl` is set |
| externalDatabase.jdbcUrl | string | `""` | Full JDBC URL, overrides host/port/database (e.g. to add `?sslmode=require`) |
| externalDatabase.password | string | `""` | Stored in a Secret created by the chart. Prefer `existingSecret`. |
| externalS3 | object | `{"accessKey":"","allowPrivateEndpoints":false,"bucket":"","endpoint":"","existingSecret":"","existingSecretAccessKeyKey":"access-key","existingSecretSecretKeyKey":"secret-key","pathStyleAccess":false,"region":"us-east-1","secretKey":""}` | Your S3-compatible bucket, used in cluster mode for job files (and for stored files with a licence) |
| externalS3.accessKey | string | `""` | Leave both keys and `existingSecret` empty to use the AWS default credential chain (e.g. IRSA) |
| externalS3.allowPrivateEndpoints | bool | `false` | Must be true when the endpoint resolves to a private IP (e.g. an in-cluster server) |
| externalS3.endpoint | string | `""` | Blank uses AWS's regional endpoint; otherwise the full URL, e.g. https://<account>.r2.cloudflarestorage.com |
| externalS3.pathStyleAccess | bool | `false` | true for MinIO/Ceph style servers, false for AWS |
| externalValkey | object | `{"database":0,"existingSecret":"","existingSecretPasswordKey":"password","host":"","password":"","port":6379,"tls":false,"username":""}` | Your Valkey or Redis server (standalone), used in cluster mode. It must run with `maxmemory-policy noeviction`. |
| externalValkey.database | int | `0` | Database index, so two installs can share one server |
| externalValkey.password | string | `""` | Stored in a Secret created by the chart. Prefer `existingSecret`. |
| externalValkey.tls | bool | `false` | Use TLS (`rediss://`) |
| extraArgs | list | `[]` |  |
| httpRoute | object | `{"annotations":{},"enabled":false,"hostnames":[],"labels":{},"parentRefs":[],"rules":[]}` | HTTPRoute (Gateway API) for load balancing. When enabled, an HTTPRoute resource is rendered alongside (or instead of) the Ingress. |
| httpRoute.annotations | object | `{}` | Stirling-pdf HTTPRoute annotations |
| httpRoute.hostnames | list | `[]` | HTTPRoute hostnames. Must match the host the client requests. |
| httpRoute.labels | object | `{}` | Stirling-pdf HTTPRoute labels |
| httpRoute.parentRefs | list | `[]` | HTTPRoute parentRefs (the Gateway(s) this route attaches to). Must be provided if HTTPRoute is enabled. See https://gateway-api.sigs.k8s.io/api-types/httproute/#attaching-to-gateways |
| httpRoute.rules | list | `[]` | HTTPRoute rules. If empty, a default rule is rendered that routes all traffic to the chart's own Service on service.externalPort. |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.registry | string | `"docker.stirlingpdf.com"` |  |
| image.repository | string | `"stirlingtools/stirling-pdf"` |  |
| image.sha | string | `""` |  |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| ingress | object | `{"annotations":{},"enabled":false,"hosts":[],"ingressClassName":null,"labels":{},"pathType":"ImplementationSpecific"}` | Ingress for load balancer |
| ingress.annotations | object | `{}` | Stirling-pdf Ingress annotations |
| ingress.hosts | list | `[]` | Must be provided if Ingress is enabled |
| ingress.ingressClassName | string | `nil` | See https://kubernetes.io/blog/2020/04/02/improvements-to-the-ingress-api-in-kubernetes-1.18/#specifying-the-class-of-an-ingress |
| ingress.labels | object | `{}` | Stirling-pdf Ingress labels |
| nodeSelector | object | `{}` |  |
| persistence.accessMode | string | `"ReadWriteOnce"` |  |
| persistence.enabled | bool | `false` |  |
| persistence.labels | object | `{}` |  |
| persistence.path | string | `"/configs"` | Mount path of the storage volume. /configs holds settings.yml, the embedded database, keys and backups, so it is the directory worth persisting. |
| persistence.pv | object | `{"accessMode":"ReadWriteOnce","capacity":{"storage":"8Gi"},"enabled":false,"nfs":{"path":null,"server":null},"pvname":null}` | stirling-pdf data Persistent Volume Storage Class If defined, storageClassName: <storageClass> If set to "-", storageClassName: "", which disables dynamic provisioning If undefined (the default) or set to null, no storageClassName spec is   set, choosing the default provisioner.  (gp2 on AWS, standard on   GKE, AWS & OpenStack) storageClass: "-" volumeName: |
| persistence.size | string | `"8Gi"` |  |
| podAnnotations | object | `{}` | Read more about kube2iam to provide access to s3 https://github.com/jtblin/kube2iam |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | PodDisruptionBudget for the Stirling-PDF pods. Only useful with 2 or more replicas. |
| podLabels | object | `{}` | ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| premium | object | `{"enabled":false,"existingSecret":"","existingSecretKey":"premium-key","key":""}` | Licence settings (Stirling-PDF `premium.*`). A Server or Enterprise licence is required for cluster mode, and for any processing when an external database (PostgreSQL) is used. |
| premium.enabled | bool | `false` | Turn licence checks on (sets PREMIUM_ENABLED) |
| premium.existingSecret | string | `""` | Name of an existing Secret that holds the licence key |
| premium.existingSecretKey | string | `"premium-key"` | Key inside `existingSecret` that holds the licence key |
| premium.key | string | `""` | Licence key. Stored in a Secret created by the chart. Prefer `existingSecret`. |
| priorityClassName | string | `""` |  |
| probes.liveness.enabled | bool | `true` |  |
| probes.liveness.failureThreshold | int | `3` |  |
| probes.liveness.initialDelaySeconds | int | `5` |  |
| probes.liveness.periodSeconds | int | `10` |  |
| probes.liveness.successThreshold | int | `1` |  |
| probes.liveness.timeoutSeconds | int | `5` |  |
| probes.livenessHttpGetConfig.scheme | string | `"HTTP"` |  |
| probes.readiness.enabled | bool | `true` |  |
| probes.readiness.failureThreshold | int | `3` |  |
| probes.readiness.initialDelaySeconds | int | `5` |  |
| probes.readiness.periodSeconds | int | `10` |  |
| probes.readiness.successThreshold | int | `1` |  |
| probes.readiness.timeoutSeconds | int | `5` |  |
| probes.readinessHttpGetConfig.scheme | string | `"HTTP"` |  |
| probes.startup.enabled | bool | `true` |  |
| probes.startup.failureThreshold | int | `60` |  |
| probes.startup.initialDelaySeconds | int | `10` |  |
| probes.startup.periodSeconds | int | `10` |  |
| probes.startup.successThreshold | int | `1` |  |
| probes.startup.timeoutSeconds | int | `5` |  |
| probes.startupHttpGetConfig | object | `{}` | Left empty, the startup probe uses `livenessHttpGetConfig` |
| replicaCount | int | `1` | Number of Stirling-PDF pods. More than 1 needs `cluster.enabled: true`. |
| resources | object | `{}` | CPU and memory for the Stirling-PDF container. The image sizes the Java heap from the memory limit (55-70% of it), so always set a memory limit. |
| rootPath | string | `"/"` | Rootpath for the application |
| secret.labels | object | `{}` |  |
| securityContext | object | `{"enabled":true,"fsGroup":1000}` | Pod-level securityContext. Every key except `enabled` is passed through as-is. UID/GID 1000 is the default user "stirling-pdf" used in the container image starting in v0.8.0 and above. This is required for local persistent storage. If your cluster does not allow this, try setting securityContext: {} |
| service.annotations | object | `{}` |  |
| service.externalPort | int | `8080` |  |
| service.externalTrafficPolicy | string | `"Local"` |  |
| service.ipFamilies | list | `[]` | Can be IPv4 and/or IPv6 |
| service.ipFamilyPolicy | string | `""` | set the ip family policy to configure dual-stack |
| service.labels | object | `{}` |  |
| service.loadBalancerIP | string | `nil` | Only valid if service.type: LoadBalancer |
| service.loadBalancerSourceRanges | list | `[]` | Only valid if service.type: LoadBalancer |
| service.nodePort | string | `nil` |  |
| service.servicename | string | `nil` |  |
| service.sessionAffinity | string | `""` | `ClientIP` pins each client to one pod, for clients that poll async jobs in cluster mode. Ingress controllers bypass this; use their sticky-cookie setting instead. |
| service.sessionAffinityConfig | object | `{}` | e.g. `{clientIP: {timeoutSeconds: 10800}}` |
| service.targetPort | string | `nil` | from deployment above. Leave empty to use stirling-pdf directly. |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automountServiceAccountToken | bool | `false` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| serviceMonitor.enabled | bool | `false` |  |
| serviceMonitor.labels | object | `{}` |  |
| serviceMonitor.metricsPath | string | `"/metrics"` |  |
| sharedKeys | object | `{"automaticallyGeneratedKey":"","automaticallyGeneratedUuid":"","credentialEncryptionKey":"","existingSecret":""}` | Keys every pod must share. Used when a database or cluster mode is on; otherwise the app keeps its own keys in /configs. Left empty, the chart generates them once and keeps them across upgrades. |
| sharedKeys.automaticallyGeneratedKey | string | `""` | AUTOMATICALLYGENERATED_KEY (any UUID) |
| sharedKeys.automaticallyGeneratedUuid | string | `""` | AUTOMATICALLYGENERATED_UUID (any UUID) |
| sharedKeys.credentialEncryptionKey | string | `""` | STIRLING_CREDENTIAL_ENCRYPTION_KEY: base64 of 32 random bytes (`openssl rand -base64 32`) |
| sharedKeys.existingSecret | string | `""` | Existing Secret with the keys `credential-encryption-key` (base64 of 32 random bytes), `automatically-generated-key` and `automatically-generated-uuid`. Required for `helm template`/GitOps. |
| strategy | object | `{}` | Deployment update strategy. Left empty, a single pod with a persistent volume gets `RollingUpdate` with `maxSurge: 0`, so the old pod stops before the new one opens the same embedded database. |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` | Spread pods across nodes or zones, for example `[{maxSkew: 1, topologyKey: kubernetes.io/hostname, whenUnsatisfiable: ScheduleAnyway, labelSelector: {matchLabels: {app.kubernetes.io/instance: <release>}}}]` |
| volumePermissions | object | `{"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"library/busybox","tag":"1.37"}}` | volumePermissions: Change the owner of the persistent volume mountpoint to RunAsUser:fsGroup. Only used when securityContext.enabled is false and persistence is on. |
| waitForDependencies | object | `{"enabled":true,"resources":{}}` | Wait in an init container until the database and Valkey accept TCP connections, so the app does not crash-loop while they start. Uses the Stirling-PDF image, so nothing extra is pulled. |
