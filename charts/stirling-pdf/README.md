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

## Quick start

```console
helm repo add stirling-pdf https://stirling-tools.github.io/Stirling-PDF-chart
helm repo update
helm install stirling-pdf stirling-pdf/stirling-pdf-chart
```

This starts one Stirling-PDF pod with its built-in database. Follow the printed notes to open it
(by default through `kubectl port-forward`). The default login is `admin` / `stirling`, and the app
asks you to change the password on first login.

## New to Helm?

A few terms used throughout this page:

- A **chart** is a package of Kubernetes manifests with placeholders. This repository is a chart.
- A **release** is one installed copy of a chart. `stirling-pdf` in `helm install stirling-pdf ...` is the release name.
- **Values** fill in the placeholders. Every setting and its default is listed in `values.yaml`
  and in the [Values](#values) table below. See them with `helm show values stirling-pdf/stirling-pdf-chart`.

You change values in one of two ways:

- `--set key=value` on the command line, for one or two settings:
  `helm install stirling-pdf stirling-pdf/stirling-pdf-chart --set persistence.enabled=true`.
  Nested keys use dots, list items use `[0]`, e.g. `--set envs[0].name=UI_APPNAME --set envs[0].value=PDF`.
- `-f my-values.yaml` with a file that holds only the settings you want to change. This is easier to
  read, review and keep in git, so prefer it for anything beyond a quick test. Copy one of the
  files in [`examples/`](examples/) as a starting point.

Both can be combined; later flags win. Useful commands:

```console
helm template stirling-pdf stirling-pdf/stirling-pdf-chart -f my-values.yaml   # print the manifests, install nothing
helm install stirling-pdf stirling-pdf/stirling-pdf-chart -f my-values.yaml    # install
helm upgrade stirling-pdf stirling-pdf/stirling-pdf-chart -f my-values.yaml    # apply changed values or a new chart version
helm get values stirling-pdf                                                   # show what you set
helm uninstall stirling-pdf                                                    # remove the release
```

If a combination of values cannot work (for example two replicas without cluster mode), the chart
stops with an error message that says what to change, before anything is created.

## Choosing a setup

Everything beyond the first option is optional and off by default.

1. **Single node, built-in database** (default). One pod, an embedded H2 database in `/configs`.
   Turn on `persistence.enabled` so settings, users and keys survive pod restarts.
   Example: [`examples/single-node.yaml`](examples/single-node.yaml).
2. **Single node with PostgreSQL**. Same, but users and data live in PostgreSQL.
   Needs a Server or Enterprise licence (see [Licence](#licence)).
   Example: [`examples/single-node-postgres.yaml`](examples/single-node-postgres.yaml).
3. **Multi-node, bundled services**. Several pods sharing a PostgreSQL, a Valkey and an S3 server
   that the chart deploys for you. Good for trying multi-node and for small installs.
   Example: [`examples/multi-node-bundled.yaml`](examples/multi-node-bundled.yaml).
4. **Multi-node, your own services**. Same, but pointed at managed PostgreSQL, Valkey/Redis and S3.
   This is the recommended production setup.
   Example: [`examples/multi-node-external.yaml`](examples/multi-node-external.yaml).

### How the optional services work

Each backing service has a bundled mode and an external mode. Use one, not both:

| Service | Bundled (the chart runs it) | External (you run it) |
|---------|-----------------------------|-----------------------|
| PostgreSQL | `postgresql.enabled: true` | `externalDatabase.host` (or `jdbcUrl`) |
| Valkey (or Redis) | `valkey.enabled: true` | `externalValkey.host` |
| S3 object storage | `s3.enabled: true` | `externalS3.bucket` |

Bundled services are single-pod StatefulSets with their own volume, built from official images
(`postgres`, `valkey/valkey`) and [Silo](https://github.com/pgsty/silo) for S3. They have no
replication or backups; for production use managed services.

Downloads of files users store on the server are redirects to a presigned S3 URL. With the bundled
S3 that URL uses the in-cluster service name, which a browser cannot reach, so use `externalS3`
with a publicly reachable endpoint when users store files.

`cluster.enabled: true` switches the app into multi-node mode. The chart then sets every
`CLUSTER_*`, `SYSTEM_DATASOURCE_*` and `STORAGE_S3_*` variable from whichever mode you chose, so you
do not set those yourself. It also adds `POD_IP` and a node id (the pod name) to each pod.

Credentials never appear as plain values in the Deployment. You can either give the password in
values (the chart stores it in a Secret) or, better, point at your own Secret with the
`existingSecret` keys. Passwords and keys the chart generates are kept across `helm upgrade`.

### Why Silo for the bundled S3 server

MinIO stopped publishing its community container images in 2025 (`minio/minio` and
`quay.io/minio/minio` can no longer be pulled). [Silo](https://github.com/pgsty/silo) is a
maintained fork of MinIO by the Pigsty project: same server, same `MINIO_ROOT_*` settings and `mc`
client, published for amd64 and arm64, small (about 57 MB), and it runs as any non-root user. It is
also the S3 server Stirling-PDF's own multi-node test stack uses. SeaweedFS and Garage were
considered, but both need extra bootstrap steps (identities, cluster layout, key import) before a
bucket can be used. Silo is AGPL-3.0 licensed, like MinIO. Any S3-compatible service works in
external mode.

## Licence

Some setups need a paid Stirling-PDF licence:

- **Cluster mode** (`cluster.enabled`) needs a Server or Enterprise licence. The app refuses to
  start without one, so the chart stops with an error unless `premium.enabled` is set.
- **PostgreSQL** (bundled or external): without a licence the app starts, but every processing
  request is refused with HTTP 402 until one is added.
- **S3 storage** (`s3.enabled` or `externalS3`): the chart only switches the app's file storage to
  S3 when `premium.enabled` is set, because the app refuses to start with S3 storage and no licence.

Store the key in a Secret and reference it:

```console
kubectl create secret generic stirling-licence --from-literal=premium-key=<your licence key>
```

```yaml
premium:
  enabled: true
  existingSecret: stirling-licence
```

## Persistence

- **Single node**: the app keeps its settings, embedded database and keys in `/configs`. With
  `persistence.enabled: true` that directory is a PersistentVolumeClaim, and files users store on the
  server go to `/configs/storage` on the same volume. Updates use `maxSurge: 0`, so the old pod stops
  before the new one starts, because two pods cannot open the same embedded database (the new pod
  would crash-loop on "The file is locked").
- **Multi-node**: all shared state lives in PostgreSQL, Valkey and S3, so each pod gets a fresh
  `/configs` and `persistence` stays off. The chart refuses `persistence.enabled` with more than one
  pod unless the volume is `ReadWriteMany`.
- Settings changed in the admin UI are written to the local `/configs/settings.yml` of the pod that
  handled the request. In multi-node mode, set configuration through `envs` instead, so every pod
  gets it and it survives pod replacement.
- The bundled PostgreSQL, Valkey and S3 each keep data on their own volume. `helm uninstall` leaves
  those volumes, the PostgreSQL and S3 password Secrets and the shared keys Secret behind on purpose,
  so a reinstall with the same release name finds its data. Delete them with `kubectl delete pvc,secret -l app.kubernetes.io/instance=<release>`
  when you really want to start over.

## Multi-node details

### Sticky sessions

A job started with `?async=true` is only served by the pod that ran it. Other pods answer
`410 Gone` with the owning pod's name, and the client is expected to retry. Browser traffic
through an ingress should therefore stick to one pod. In cluster mode the chart adds sticky-cookie
annotations for Traefik (on the Service) and ingress-nginx (on the Ingress); turn this off with
`cluster.stickySessions: false`. For other ingress controllers, enable cookie affinity yourself.
Plain API calls (without `async=true`) work on any pod.

If a pod is removed, results of the jobs it ran can no longer be fetched from the other pods,
although the files stay in S3 until they expire. Clients have to run such a job again.

### Failover

Rolling updates and pod deletions (scale-down, node drains) complete without failed requests: pods
stop receiving traffic before they shut down (`deployment.preStopSleepSeconds`). When a pod crashes
outright, requests already routed to it fail for a few seconds until Kubernetes notices. With
Traefik, add a retry middleware to hide this; ingress-nginx retries connection errors by default.

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: stirling-retry
spec:
  retry:
    attempts: 3
    initialInterval: 100ms
```

```yaml
ingress:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: <namespace>-stirling-retry@kubernetescrd
```

### Keys shared by every pod

In cluster mode, and whenever PostgreSQL is used, every pod needs the same
`STIRLING_CREDENTIAL_ENCRYPTION_KEY`, `AUTOMATICALLYGENERATED_KEY` and `AUTOMATICALLYGENERATED_UUID`.
The chart generates them once into the Secret `<release>-stirling-pdf-chart-keys` and keeps it on
uninstall. **Back that Secret up**: losing it makes encrypted data in the database unreadable.
You can supply your own with `sharedKeys.existingSecret`.

### GitOps (`helm template`, Argo CD)

`helm template` cannot look up existing Secrets, so generated passwords and keys would change on
every render. With `helm template`, Argo CD or any tool that renders without a cluster connection,
set `sharedKeys.existingSecret`, `postgresql.auth.existingSecret`, `valkey.auth.existingSecret` and
`s3.auth.existingSecret` (or give fixed values) so the output is stable.

## Sizing and slow nodes

Measured on a single k3s node with the 3.2.0 image, CPU limit equal to request, 4Gi memory limit.
"Ready" is the time from pod creation until the readiness probe passed; there were no restarts in
any of these runs:

| CPU | Ready after |
|-----|-------------|
| 2 | 21 s |
| 1 | 41 s |
| 0.5 | 81 s |
| 0.25 | 151 s |
| 0.15 | 275 s |
| 0.1 | 444 s |

The startup probe allows 10 s + 60 x 10 s = 610 s before the kubelet restarts the container, which
covers even 0.1 CPU. Raise `probes.startup.failureThreshold` for slower nodes. Liveness and
readiness only start after startup succeeded, so a slow boot is never killed half-way.

Memory, with a limit and 2 CPUs (merge, compress and Word-to-PDF conversion tested):

- 512Mi: killed for running out of memory during boot.
- 768Mi: boots and handles PDF operations, but Word/LibreOffice conversions are killed.
- 1Gi: everything above worked; this is the practical minimum.
- 2Gi: recommended; leaves room for larger files.

The image sizes the Java heap from the memory limit (55-70% of it), so always set
`resources.limits.memory`. It also overwrites `JAVA_TOOL_OPTIONS`; to pass your own JVM flags, set
`JAVA_CUSTOM_OPTS` through `envs` (they are appended last, so they win).

In multi-node mode each pod needs the same resources. The chart waits (in an init container) until
PostgreSQL, Valkey and S3 accept connections before starting the app, so a slow database does not
cause a crash loop (`waitForDependencies.enabled`).

## Security

By default the container starts as root and the image's startup script drops to its own user
before starting Java (this is how the image works on Docker too). To run fully as non-root, which
Kubernetes Pod Security "restricted" requires, use
[`examples/restricted-security.yaml`](examples/restricted-security.yaml) (runs as uid 1001, the
image's own user). For platforms that assign a random user id, such as OpenShift, add
`deployment.arbitraryUid: true`, see [`examples/openshift-arbitrary-uid.yaml`](examples/openshift-arbitrary-uid.yaml).

The 3.x image's startup script writes to `/usr/local/bin` and needs a passwd entry for the
running user. When the pod runs as non-root the chart gives it a writable copy of `/usr/local/bin`,
and `deployment.arbitraryUid` adds the passwd entry, so no image change is needed. A read-only root
filesystem was not tested and is unlikely to work, because the startup script writes to several
image directories.

The bundled PostgreSQL, Valkey and S3 always run as non-root and meet the "restricted" standard.

## Upgrading from chart 3.x

- Upgrade with your values file (`helm upgrade <release> stirling-pdf/stirling-pdf-chart -f my-values.yaml`)
  or with `--reset-then-reuse-values` (Helm 3.14 and later). Plain `--reuse-values` does not load the
  new settings' defaults and fails with a message saying so.
- The app version moves to 3.2.0.
- `persistence.path` now defaults to `/configs` and the volume is actually mounted there (3.x never
  mounted it). If you set `persistence.path: /tmp` yourself, change it to `/configs`.
- With `persistence.enabled`, updates stop the old pod before starting the new one (`maxSurge: 0`,
  see [Persistence](#persistence)).
- Server-side file storage is on by default from app 3.2.0. With `persistence.enabled` the files go
  to `/configs/storage` on the volume; without it they are lost when the pod restarts.
- A startup probe was added and probe timeouts went from 1 s to 5 s. This fixes pods being killed
  while still booting on small nodes (issue #7503).
- `resources` now applies to the Stirling-PDF container even when sidecars are configured.
- The `volumePermissions` init container now uses `busybox` instead of `bitnami/minideb`.
- Deployment selector labels are unchanged, so no reinstall is needed.

### Moving from a single node to multi-node

Setting `cluster.enabled: true` on an existing single-node release works as an upgrade, but the
data in the embedded H2 database is **not** copied to PostgreSQL: the cluster starts with an empty
database and the default `admin` login. Turning `persistence.enabled` off at the same time deletes
the old volume. Recreate users and settings afterwards, or keep a copy of `/configs` first.

## Troubleshooting

- **Pod restarts during startup**: check `kubectl describe pod`. "Startup probe failed" many
  times means the node is slower than the startup budget; raise `probes.startup.failureThreshold`.
- **OOMKilled**: raise `resources.limits.memory` (see [Sizing](#sizing-and-slow-nodes)).
- **HTTP 402 with PostgreSQL**: add a licence (see [Licence](#licence)).
- **HTTP 410 for job results**: the request reached a different pod than the one that ran the job;
  enable sticky sessions on your ingress.
- **Pod stuck in `Init`**: the `wait-for-dependencies` init container logs which host it is waiting for.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling | object | `{"enabled":false,"maxReplicas":4,"minReplicas":2,"targetCPUUtilizationPercentage":80}` | HorizontalPodAutoscaler for the Stirling-PDF pods. Needs `cluster.enabled: true` and a metrics server. |
| cluster | object | `{"artifactKeyPrefix":"transient/","enabled":false,"stickySessions":true}` | Run Stirling-PDF as a multi-node cluster. Needs PostgreSQL, Valkey and S3 (bundled or external) plus a licence (`premium`); the chart wires the app's cluster settings from them. |
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
| externalDatabase | object | `{"database":"stirling","existingSecret":"","existingSecretPasswordKey":"password","host":"","jdbcUrl":"","password":"","port":5432,"username":"stirling"}` | An existing PostgreSQL server, used when `postgresql.enabled` is false and `host` or `jdbcUrl` is set |
| externalDatabase.jdbcUrl | string | `""` | Full JDBC URL, overrides host/port/database (e.g. to add `?sslmode=require`) |
| externalDatabase.password | string | `""` | Stored in a Secret created by the chart. Prefer `existingSecret`. |
| externalS3 | object | `{"accessKey":"","allowPrivateEndpoints":false,"bucket":"","endpoint":"","existingSecret":"","existingSecretAccessKeyKey":"access-key","existingSecretSecretKeyKey":"secret-key","pathStyleAccess":false,"region":"us-east-1","secretKey":""}` | An existing S3-compatible bucket, used when `s3.enabled` is false and `bucket` is set. The bucket must already exist. |
| externalS3.accessKey | string | `""` | Leave both keys and `existingSecret` empty to use the AWS default credential chain (e.g. IRSA) |
| externalS3.allowPrivateEndpoints | bool | `false` | Must be true when the endpoint resolves to a private IP (e.g. an in-cluster server) |
| externalS3.endpoint | string | `""` | Blank uses AWS's regional endpoint; otherwise the full URL, e.g. https://<account>.r2.cloudflarestorage.com |
| externalS3.pathStyleAccess | bool | `false` | true for MinIO/Silo/Ceph style servers, false for AWS |
| externalValkey | object | `{"database":0,"existingSecret":"","existingSecretPasswordKey":"password","host":"","password":"","port":6379,"tls":false,"username":""}` | An existing Valkey or Redis server (standalone), used when `valkey.enabled` is false. It must run with `maxmemory-policy noeviction`. |
| externalValkey.database | int | `0` | Database index, so two installs can share one server |
| externalValkey.password | string | `""` | Stored in a Secret created by the chart. Prefer `existingSecret`. |
| externalValkey.tls | bool | `false` | Use TLS (`rediss://`) |
| extraArgs | list | `[]` |  |
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
| postgresql | object | `{"affinity":{},"auth":{"database":"stirling","existingSecret":"","password":"","secretKey":"password","username":"stirling"},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"enabled":false,"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"library/postgres","tag":"18-alpine"},"nodeSelector":{},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"size":"8Gi","storageClass":""},"podSecurityContext":{"fsGroup":70,"runAsGroup":70,"runAsNonRoot":true,"runAsUser":70,"seccompProfile":{"type":"RuntimeDefault"}},"resources":{},"tolerations":[]}` | Bundled PostgreSQL (official `postgres` image). Fine for small installs; use `externalDatabase` for a managed database. |
| postgresql.auth.existingSecret | string | `""` | Existing Secret holding the password |
| postgresql.auth.password | string | `""` | Leave empty to generate one (kept across upgrades) |
| postgresql.auth.secretKey | string | `"password"` | Key inside `existingSecret` |
| postgresql.persistence.storageClass | string | `""` | "-" sets storageClassName "" (no dynamic provisioning); empty uses the cluster default |
| postgresql.podSecurityContext | object | `{"fsGroup":70,"runAsGroup":70,"runAsNonRoot":true,"runAsUser":70,"seccompProfile":{"type":"RuntimeDefault"}}` | The alpine image's postgres user is 70 |
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
| probes.startupHttpGetConfig.scheme | string | `"HTTP"` |  |
| replicaCount | int | `1` | Number of Stirling-PDF pods. More than 1 needs `cluster.enabled: true` (see the README). |
| resources | object | `{}` | CPU and memory for the Stirling-PDF container. The image sizes the Java heap from the memory limit (55-70% of it), so always set a memory limit. See the README for measured minimums. |
| rootPath | string | `"/"` | Rootpath for the application |
| s3 | object | `{"affinity":{},"auth":{"existingSecret":"","rootPassword":"","rootUser":""},"bucket":"stirling-pdf","containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"enabled":false,"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"pgsty/silo","tag":"RELEASE.2026-09-16T00-00-00Z"},"nodeSelector":{},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"size":"10Gi","storageClass":""},"podSecurityContext":{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},"resources":{},"tolerations":[]}` | Bundled S3-compatible object storage (Silo, a maintained MinIO fork). Fine for small installs; use `externalS3` for AWS S3, Cloudflare R2, Ceph and similar. |
| s3.auth.existingSecret | string | `""` | Existing Secret with the keys `root-user` and `root-password` |
| s3.auth.rootUser | string | `""` | Leave empty to generate (kept across upgrades) |
| s3.bucket | string | `"stirling-pdf"` | Bucket to create and use |
| secret.labels | object | `{}` |  |
| securityContext | object | `{"enabled":true,"fsGroup":1000}` | Pod-level securityContext. Every key except `enabled` is passed through as-is. UID/GID 1000 is the default user "stirling-pdf" used in the container image starting in v0.8.0 and above. This is required for local persistent storage. If your cluster does not allow this, try setting securityContext: {} See examples/restricted-security.yaml for a Pod Security "restricted" setup. |
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
| service.sessionAffinity | string | `""` | `ClientIP` pins each client to one pod, for clients that poll async jobs in cluster mode. Ingress controllers bypass this; use their sticky-cookie setting instead (see the README). |
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
| valkey | object | `{"affinity":{},"auth":{"enabled":true,"existingSecret":"","password":"","secretKey":"password"},"containerSecurityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"enabled":false,"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"valkey/valkey","tag":"9-alpine"},"nodeSelector":{},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"size":"1Gi","storageClass":""},"podSecurityContext":{"fsGroup":999,"runAsGroup":999,"runAsNonRoot":true,"runAsUser":999,"seccompProfile":{"type":"RuntimeDefault"}},"resources":{},"tolerations":[]}` | Bundled Valkey for cluster mode (official `valkey/valkey` image) |
| valkey.auth.password | string | `""` | Leave empty to generate one (kept across upgrades) |
| valkey.persistence | object | `{"accessMode":"ReadWriteOnce","enabled":true,"size":"1Gi","storageClass":""}` | Append-only file on a volume, so in-flight job state survives a Valkey restart |
| valkey.podSecurityContext | object | `{"fsGroup":999,"runAsGroup":999,"runAsNonRoot":true,"runAsUser":999,"seccompProfile":{"type":"RuntimeDefault"}}` | The image's valkey user is 999 |
| volumePermissions | object | `{"image":{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"library/busybox","tag":"1.37"}}` | volumePermissions: Change the owner of the persistent volume mountpoint to RunAsUser:fsGroup. Only used when securityContext.enabled is false and persistence is on. |
| waitForDependencies | object | `{"enabled":true,"resources":{}}` | Wait in an init container until the database, Valkey and S3 accept TCP connections, so the app does not crash-loop while they start. Uses the Stirling-PDF image, so nothing extra is pulled. |
