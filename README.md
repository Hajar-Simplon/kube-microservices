# Kubernetes Microservices Deployment

Deploy a complete microservices application on Kubernetes using Deployments and Services.

The application is composed of three Go microservices:

- **API Gateway**
- **Books Service**
- **Movies Service**

The API Gateway aggregates responses from the Books and Movies services and is the only application exposed outside the Kubernetes cluster.

---

# Architecture

```text
                            Client
                               │
                               ▼
                     NodePort Service
                      (api-service)
                               │
                               ▼
                    API Deployment (2 replicas)
                               │
                               ▼
                        API ConfigMap
               ┌─────────────────────────┐
               │ BOOKS_API_HOST          │
               │ MOVIES_API_HOST         │
               └─────────────────────────┘
                               │
          ┌────────────────────┴────────────────────┐
          │                                         │
          ▼                                         ▼
    books-service                           movies-service
      ClusterIP                               ClusterIP
          │                                         │
          ▼                                         ▼
   Books Deployment                         Movies Deployment
      (2 replicas)                            (2 replicas)
```

---

# Technologies

- Kubernetes
- Kind
- Docker
- Go
- kubectl

---

# Project Structure

```text
.
├── Dockerfile
├── Makefile
├── README.md
├── kind-config.yaml
├── cmd/
│   ├── api/
│   ├── books/
│   └── movies/
│
└── k8s/
    ├── namespace.yaml
    ├── configmap.yaml
    ├── api-deployment.yaml
    ├── api-service.yaml
    ├── books-deployment.yaml
    ├── books-service.yaml
    ├── movies-deployment.yaml
    └── movies-service.yaml
```

---

# Prerequisites

- Docker
- Kind
- kubectl

Verify the installation:

```bash
docker --version
kind version
kubectl version --client
```

---

# Create the Kind Cluster

Create a Kind cluster with one control-plane and two worker nodes.

**kind-config.yaml**

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

Create the cluster:

```bash
kind create cluster --config kind-config.yaml
```

Verify:

```bash
kubectl get nodes
```

Expected:

```text
NAME                 STATUS   ROLES
kind-control-plane   Ready    control-plane
kind-worker          Ready
kind-worker2         Ready
```

---

# Build the Docker Image

```bash
docker build -t kube-microservices:latest .
```

Verify:

```bash
docker images
```

---

# Load the Image into Kind

Since Kind nodes cannot directly access local Docker images, load the image into the cluster:

```bash
kind load docker-image kube-microservices:latest
```

---

# Deploy the Application

Create the namespace:

```bash
kubectl apply -f k8s/namespace.yaml
```

Deploy the microservices:

```bash
kubectl apply -f k8s/books-deployment.yaml
kubectl apply -f k8s/books-service.yaml

kubectl apply -f k8s/movies-deployment.yaml
kubectl apply -f k8s/movies-service.yaml

kubectl apply -f k8s/api-deployment.yaml
kubectl apply -f k8s/api-service.yaml
```

---

# Verify the Deployments

```bash
kubectl get deployments -n microservices
```

Expected:

```text
NAME     READY
api      2/2
books    2/2
movies   2/2
```

---

# Verify the Pods

```bash
kubectl get pods -n microservices
```

Expected:

```text
api-xxxxxxxxxx
api-xxxxxxxxxx

books-xxxxxxxx
books-xxxxxxxx

movies-xxxxxxxx
movies-xxxxxxxx
```

---

# Verify the Services

```bash
kubectl get svc -n microservices
```

Expected:

```text
NAME             TYPE
api-service      NodePort
books-service    ClusterIP
movies-service   ClusterIP
```

---

# Verify Service Discovery

```bash
kubectl get endpointslices -n microservices
```

Each Service should expose two endpoints corresponding to its two replicas.

---

# Access the Application

Expose the API locally:

```bash
kubectl port-forward service/api-service 8080:80 -n microservices
```

Open:

```
http://localhost:8080/data
```

or

```bash
curl http://localhost:8080/data
```

Expected response:

```json
{
  "app": "API Gateway",
  "data": {
    "books": [
      "Book 1",
      "Book 2",
      "Book 3"
    ],
    "movies": [
      "Movie 1",
      "Movie 2",
      "Movie 3"
    ]
  }
}
```

---

# Bonus Features

## Resource Requests and Limits

Each microservice defines CPU and memory requests and limits to improve resource management and ensure fair scheduling across the cluster.

Example configuration:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"
```

### Benefits

- Guarantees minimum CPU and memory for each container.
- Prevents a single container from consuming all node resources.
- Improves cluster stability.
- Enables Kubernetes to make better scheduling decisions.

The configured Pods belong to the **Burstable** QoS class because the requests are lower than the limits.

---

## Pod Anti-Affinity

Pod Anti-Affinity was configured to improve application availability by distributing replicas of the same microservice across different worker nodes whenever possible.

Example:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - api
          topologyKey: kubernetes.io/hostname
```

The same rule is applied to the **Books** and **Movies** deployments.

### Benefits

- Improves High Availability.
- Reduces the impact of a node failure.
- Ensures replicas are spread across multiple worker nodes.
- Demonstrates Kubernetes scheduling capabilities.

---
## ConfigMap

The API Gateway configuration is externalized using a Kubernetes ConfigMap.

Instead of hardcoding environment variables inside the Deployment, the API reads them from the ConfigMap.

Example:

```yaml
apiVersion: v1
kind: ConfigMap

metadata:
  name: api-config
  namespace: microservices

data:
  BOOKS_API_HOST: books-service
  MOVIES_API_HOST: movies-service
```

The Deployment references the ConfigMap using `configMapKeyRef`:

```yaml
env:
  - name: BOOKS_API_HOST
    valueFrom:
      configMapKeyRef:
        name: api-config
        key: BOOKS_API_HOST

  - name: MOVIES_API_HOST
    valueFrom:
      configMapKeyRef:
        name: api-config
        key: MOVIES_API_HOST
```

### Benefits

- Separates configuration from application code.
- Makes configuration easier to update.
- Improves portability across environments.
- Follows Kubernetes configuration best practices.

---

# High Availability

The Kind cluster contains:

- 1 Control Plane
- 2 Worker Nodes

With Pod Anti-Affinity enabled, Kubernetes schedules replicas on different worker nodes whenever possible.

Example distribution:

```text
kind-worker                  kind-worker2

API Pod 1                    API Pod 2
Books Pod 1                  Books Pod 2
Movies Pod 1                 Movies Pod 2
```

If one worker node becomes unavailable, another replica remains available on the second node.

---

# Verification

Check all resources:

```bash
kubectl get all -n microservices
```

Check Pod placement:

```bash
kubectl get pods -o wide -n microservices
```

Verify resource allocation:

```bash
kubectl describe pod <pod-name> -n microservices
```

The output should include:

```text
Requests:
  cpu:     100m
  memory:  128Mi

Limits:
  cpu:     250m
  memory:  256Mi
```

Verify rollout status:

```bash
kubectl rollout status deployment/api -n microservices
kubectl rollout status deployment/books -n microservices
kubectl rollout status deployment/movies -n microservices
```

---

# Kubernetes Resources

| Resource | Purpose |
|----------|---------|
| Namespace | Isolates the application resources |
| Deployment | Manages Pods and replicas |
| ReplicaSet | Maintains the desired number of Pods |
| Service | Provides networking and load balancing |
| ClusterIP | Internal communication between microservices |
| NodePort | Exposes the API Gateway outside the cluster |


---

# Service Communication

```text
Browser
    │
    ▼
api-service (NodePort)
    │
    ▼
API Pods
    │
    ├──────────► ConfigMap
    │
    ├──────────► books-service
    │                 │
    │                 ▼
    │            Books Pods
    │
    └──────────► movies-service
                      │
                      ▼
                 Movies Pods
```

The API communicates with the backend services using Kubernetes DNS:

- `books-service`
- `movies-service`

No Pod IP addresses are used.

---

# Useful Commands

List all resources:

```bash
kubectl get all -n microservices
```

List Pods:

```bash
kubectl get pods -o wide -n microservices
```

Describe a Pod:

```bash
kubectl describe pod <pod-name> -n microservices
```

Display logs:

```bash
kubectl logs <pod-name> -n microservices
```

Delete the application:

```bash
kubectl delete -f k8s/
```

Delete the cluster:

```bash
kind delete cluster
```

---

# Lessons Learned

- Deploying microservices with Kubernetes Deployments.
- Exposing applications using ClusterIP and NodePort Services.
- Implementing service discovery using Kubernetes DNS.
- Managing replicas with ReplicaSets.
- Performing rolling updates.
- Configuring CPU and memory requests and limits.
- Understanding Kubernetes QoS classes.
- Improving availability using Pod Anti-Affinity.
- Scheduling Pods across multiple worker nodes.
- Monitoring and troubleshooting applications with `kubectl`.

---

# References

- https://kubernetes.io/docs/
- https://kind.sigs.k8s.io/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/