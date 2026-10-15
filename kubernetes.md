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

### Key Objects
| Object | Purpose |
|--------|---------|
| **Pod** | Smallest deployable unit (1+ containers) |
| **Node** | Worker machine (VM or bare metal) |
| **Cluster** | Set of nodes running containerized apps |
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
- **kubelet** - Agent ensuring containers run in Pods
- **kube-proxy** - Network proxy maintaining network rules
- **Container Runtime** - Docker, containerd, CRI-O

---

## Workloads

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
| Type | Use Case |
|------|----------|
| **StatefulSet** | Stateful apps (databases) |
| **DaemonSet** | Node-level agents (logging, monitoring) |
| **Job** | One-time batch tasks |
| **CronJob** | Scheduled recurring tasks |

---

## Services & Networking

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
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## Storage

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