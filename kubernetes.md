# Kubernetes Guide: Beginner to Advanced

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [Architecture](#architecture)
3. [Workloads](#workloads)
4. [Services & Networking](#services--networking)
5. [Storage](#storage)
6. [Configuration](#configuration)
7. [Security](#security)
8. [Observability](#observability)
9. [Advanced Topics](#advanced-topics)
10. [Common Commands](#common-commands)

---

## Core Concepts

### What is Kubernetes?
Container orchestration platform for automating deployment, scaling, and management of containerized applications.
- Declarative: you define desired state (3 replicas), controllers drive reality to match.
- Self-healing: restarts failed containers, reschedules dead nodes, kills unhealthy pods.
- Portable: same manifests run on minikube, EKS, GKE, AKS.

### Key Objects
| Object | Purpose |
|--------|---------|
| **Pod** | Smallest deployable unit (1+ containers sharing IP/storage) |
| **Node** | Worker machine (VM or bare metal) running kubelet + runtime |
| **Cluster** | Set of nodes + control plane running your apps |
| **Namespace** | Virtual partition to isolate teams/envs (`dev`, `prod`) |
| **Label/Selector** | Key-value tags (`app: nginx`) linking Services to Pods |
| **Control Plane** | Manages cluster state (API server, scheduler, controller manager) |
| **kubectl** | CLI for interacting with cluster |

---

## Architecture

### Control Plane Components
```
┌─────────────────────────────────────────────────────────┐
│                    API Server                           │
│              (Frontend for all operations)              │
└──────────────┬──────────────────────────┬───────────────┘
               │                          │
    ┌──────────▼──────────┐    ┌──────────▼──────────┐
    │    Scheduler        │    │ Controller Manager  │
    │ (Assigns pods to    │    │ (Maintains desired  │
    │  nodes)             │    │  state)             │
    └─────────────────────┘    └─────────────────────┘
               │                          │
    ┌──────────▼──────────────────────────▼──────────┐
    │              etcd (Key-Value Store)            │
    │         (Cluster state & config)               │
    └────────────────────────────────────────────────┘
```

### Node Components
- **kubelet** - Agent ensuring containers run in Pods (talks to API server, runs probes)
- **kube-proxy** - Network proxy maintaining iptables/IPVS rules for Services
- **Container Runtime** - Pulls images + runs containers (containerd, CRI-O)

> Flow: `kubectl apply` → API Server validates → etcd stores → Scheduler picks node → kubelet pulls image → kube-proxy wires networking.

---

## Workloads

- Pod = ephemeral, never repaired — if it dies, controller replaces it. Don't use bare Pods in prod.
- Deployment = manages ReplicaSet + rolling updates for stateless apps. Use for 90% of workloads.
- Labels must match `selector.matchLabels` ↔ `template.metadata.labels`, else Deployment won't manage Pods.

### Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

### Deployment (Recommended for production)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

### Other Workload Types
| Type | Use Case | Key detail |
|------|----------|------------|
| **StatefulSet** | Stateful apps (databases) | Stable `web-0, web-1` names + per-pod PVC |
| **DaemonSet** | Node-level agents (logging, monitoring) | One pod per node, auto-adds on new nodes |
| **Job** | One-time batch tasks | Runs to completion, `backoffLimit` retries |
| **CronJob** | Scheduled recurring tasks | Cron syntax, `concurrencyPolicy: Forbid` to avoid overlap |

---

## Services & Networking

- Service = stable virtual IP + DNS (`nginx-service.default.svc.cluster.local`) fronting ephemeral Pod IPs.
- `selector` must match Pod labels; `port` = Service port, `targetPort` = container port.
- Ingress = L7 HTTP router (host/path → Service), needs Ingress controller (nginx, ALB). NetworkPolicy = firewall, default allow-all — add `deny-all` then whitelist.

### Service Types
```yaml
# ClusterIP (default) - Internal only
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

| Type | Access | Use Case |
|------|--------|----------|
| **ClusterIP** | Internal only | Internal microservices |
| **NodePort** | Node IP:Port | External access (dev) |
| **LoadBalancer** | Cloud LB IP | Production external access |
| **ExternalName** | DNS name | External service mapping |

### Ingress (HTTP/HTTPS routing)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

### Network Policies
```yaml
# Default deny-all: blocks all ingress/egress to selected pods
# Add allow rules per app after this (zero-trust)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {} # empty = all pods in namespace
  policyTypes:
  - Ingress
  - Egress
```

---

## Storage

- Pods are ephemeral — data dies with them. Use PV/PVC for persistence.
- PV = cluster storage pool (admin/EBS provisioner creates). PVC = dev's claim (`5Gi`). Pod mounts PVC.
- StorageClass enables dynamic provisioning (no manual PV). `Retain` keeps data after delete, `Delete` wipes it. `WaitForFirstConsumer` delays binding until pod scheduled (AZ-aware).

### PersistentVolume (PV) - Cluster resource
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /mnt/data
```

### PersistentVolumeClaim (PVC) - Request for storage
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

### StorageClass - Dynamic provisioning
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

---

## Configuration

- ConfigMap = plaintext config (env vars, files). Secret = base64-encoded sensitive data (passwords, certs) — enable etcd encryption at rest.
- Consume via `env`, `envFrom`, or volume mount. Volume mounts update on change (kubelet syncs ~1min); env vars require pod restart.
- Never bake config in image — same image + different ConfigMap per env (`dev`/`prod`).

### ConfigMap - Non-sensitive config
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_MODE: "production"
  LOG_LEVEL: "info"
  config.yaml: |
    database:
      host: db.example.com
      port: 5432
```

### Secret - Sensitive data (base64 encoded)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: YWRtaW4=        # base64 encoded
  password: c2VjcmV0MTIz    # base64 encoded
```

### Usage in Pod
```yaml
spec:
  containers:
  - name: app
    envFrom:
    - configMapRef:
        name: app-config
    - secretRef:
        name: db-secret
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

---

## Security

- RBAC: Role = namespace permissions, ClusterRole = cluster-wide. Binding grants to User/Group/ServiceAccount.
- Always use least-privilege ServiceAccounts per app, not `default`. Combine with `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]` to limit exploit impact.
- Pod Security Standards: enforce `restricted` via namespace label `pod-security.kubernetes.io/enforce: restricted`.

### RBAC (Role-Based Access Control)
```yaml
# Role (namespace-scoped)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]

# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### ClusterRole (cluster-scoped)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```

### Security Contexts
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

### Pod Security Standards
| Profile | Description |
|---------|-------------|
| **Privileged** | Unrestricted (avoid) |
| **Baseline** | Minimally restrictive |
| **Restricted** | Heavily restricted (recommended) |

---

## Observability

- Requests = guaranteed scheduling (scheduler fits sum(requests) ≤ node allocatable). Limits = max throttle/kill (`cpu` throttles, `memory` OOMKills).
- Probes: `liveness` restarts stuck container, `readiness` removes from Service during startup, `startup` extends grace for slow boots.
- Metrics Server feeds `kubectl top` + HPA; logs via `kubectl logs`, aggregate with Loki/ELK in prod.

### Resource Requests & Limits
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Health Probes
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /startup
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

### Metrics & Logging
```bash
# Metrics Server (required for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check metrics
kubectl top nodes
kubectl top pods -n <namespace>

# Logs
kubectl logs <pod-name> -c <container-name> --tail=100 -f
```

---

## Advanced Topics

- HPA scales replicas on CPU/memory/custom metrics (needs requests set + Metrics Server). VPA resizes requests/limits (don't use both on same metric — they fight).
- Cluster Autoscaler adds/removes nodes when pods pend; Karpenter (AWS) is faster, bin-packing provisioner.
- Helm = templated packages (`values.yaml` overrides); Kustomize = overlay patches without templates (`bases` + `patches`). Operators = CRD + controller encoding ops knowledge (e.g. Postgres failover).

### Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 0
```

### Vertical Pod Autoscaler (VPA)
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: nginx-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: nginx-deployment
  updatePolicy:
    updateMode: "Auto"
```

### Cluster Autoscaler
- Automatically adjusts node count based on pod scheduling needs
- Requires cloud provider integration (AWS, GCP, Azure)

### Helm - Package Manager
```bash
# Install chart
helm install my-release nginx-ingress/nginx-ingress

# Upgrade
helm upgrade my-release nginx-ingress/nginx-ingress

# Template (dry-run)
helm template my-release nginx-ingress/nginx-ingress

# Create chart
helm create my-chart
```

### Kustomize - Native Configuration
```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app: my-app

images:
- name: nginx
  newTag: "1.25"
```

### Operators - Custom Controllers
Extend Kubernetes API for domain-specific applications (databases, monitoring, etc.)

```bash
# Install Operator SDK
# Create operator
operator-sdk init --domain example.com --repo github.com/example/memcached-operator
operator-sdk create api --group cache --version v1alpha1 --kind Memcached --resource --controller
```

### Service Mesh (Istio/Linkerd)
```yaml
# Istio sidecar injection
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
```

---

## Common Commands

- `get` = list, `describe` = details + events, `logs` = stdout, `exec` = shell in, `apply` = declarative sync.
- Debug order: `get pods` → `describe pod` (events) → `logs` → `exec` → `get events --sort-by`.

### Cluster Info
```bash
kubectl cluster-info
kubectl version
kubectl get nodes -o wide
kubectl get namespaces
```

### Workload Management
```bash
# Create
kubectl apply -f deployment.yaml
kubectl create deployment nginx --image=nginx

# Scale
kubectl scale deployment nginx --replicas=5

# Update
kubectl set image deployment/nginx nginx=nginx:1.25
kubectl rollout status deployment/nginx
kubectl rollout undo deployment/nginx

# Debug
kubectl describe pod <pod-name>
kubectl exec -it <pod-name> -- /bin/sh
kubectl logs <pod-name> -f --tail=100
```

### Service & Networking
```bash
kubectl get svc -o wide
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl port-forward svc/nginx 8080:80
```

### Config & Secrets
```bash
kubectl create configmap app-config --from-literal=KEY=value
kubectl create secret generic db-secret --from-literal=password=secret
kubectl get configmap app-config -o yaml
```

### Troubleshooting
```bash
# Events
kubectl get events --sort-by=.metadata.creationTimestamp

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# API resources
kubectl api-resources
kubectl explain pod.spec.containers

# Force delete
kubectl delete pod <name> --grace-period=0 --force
```

### Context & Config
```bash
kubectl config get-contexts
kubectl config use-context <context-name>
kubectl config set-context --current --namespace=<namespace>
```

---

## Best Practices Summary

- Why: bare Pods have no self-healing, missing limits cause noisy-neighbor OOMs, `:latest` breaks rollbacks, open RBAC + root containers widen blast radius.

| Category | Practice |
|----------|----------|
| **Deployments** | Always use Deployments over raw Pods |
| **Resources** | Set requests/limits for all containers |
| **Health** | Implement liveness/readiness/startup probes |
| **Security** | Run as non-root, drop capabilities, use RBAC |
| **Config** | Externalize config via ConfigMaps/Secrets |
| **Storage** | Use PVCs with StorageClasses for dynamic provisioning |
| **Networking** | Use NetworkPolicies for zero-trust |
| **Observability** | Structured logging, metrics, distributed tracing |
| **Updates** | Use rolling updates, configure PDBs |
| **Backup** | Velero for cluster backup/restore |

---

## Learning Path

1. **Beginner**: Pods, Deployments, Services, ConfigMaps, Secrets
2. **Intermediate**: Ingress, Persistent Volumes, RBAC, Health Probes, HPA
3. **Advanced**: Operators, Service Mesh, Custom Controllers, CRDs, Cluster Autoscaling
4. **Expert**: Multi-cluster, GitOps (ArgoCD/Flux), Security Hardening, Performance Tuning

---

## Resources
- [Official Documentation](https://kubernetes.io/docs/)
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CKA/CKAD Study Guide](https://github.com/cncf/curriculum)
- [Kubernetes Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)