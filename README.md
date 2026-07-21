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
                    API Deployment
                     (2 replicas)
                           │
          ┌────────────────┴────────────────┐
          │                                 │
          ▼                                 ▼
   books-service                    movies-service
     ClusterIP                         ClusterIP
          │                                 │
   Books Deployment                 Movies Deployment
     (2 replicas)                     (2 replicas)
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
├── README.md
├── kind-config.yaml
├── cmd/
│   ├── api/
│   ├── books/
│   └── movies/
│
└── k8s/
    ├── namespace.yaml
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

```
Browser
    │
    ▼
api-service (NodePort)
    │
    ▼
API Pods
    │
    ├──────────────► books-service
    │                    │
    │                    ▼
    │               Books Pods
    │
    └──────────────► movies-service
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

- Deploying applications using Kubernetes Deployments.
- Managing application replicas with ReplicaSets.
- Exposing applications using Kubernetes Services.
- Internal communication using ClusterIP Services.
- External access using a NodePort Service.
- Service discovery using Kubernetes DNS.
- Load balancing across multiple Pods.
- Isolating resources using Namespaces.

---

# References

- https://kubernetes.io/docs/
- https://kind.sigs.k8s.io/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/