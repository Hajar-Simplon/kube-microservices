# ==========================================
# Kubernetes Microservices - KIND
# ==========================================

CLUSTER_NAME = kind
NAMESPACE = microservices
MANIFESTS = k8s

.PHONY: cluster delete-cluster deploy destroy status pods deployments services endpoints api-logs books-logs movies-logs shell port-forward

## Create KIND cluster
cluster:
	kind create cluster --config kind-config.yaml

## Delete KIND cluster
delete-cluster:
	kind delete cluster

## Deploy all manifests
deploy:
	kubectl apply -f $(MANIFESTS)/

## Delete all manifests
destroy:
	kubectl delete -f $(MANIFESTS)/

## Show cluster status
status:
	kubectl cluster-info
	kubectl get nodes

## Show Pods
pods:
	kubectl get pods -o wide -n $(NAMESPACE)

## Show Deployments
deployments:
	kubectl get deployments -n $(NAMESPACE)

## Show Services
services:
	kubectl get svc -n $(NAMESPACE)

## Show EndpointSlices
endpoints:
	kubectl get endpointslices -n $(NAMESPACE)

## View API logs
api-logs:
	kubectl logs deployment/api -n $(NAMESPACE)

## View Books logs
books-logs:
	kubectl logs deployment/books -n $(NAMESPACE)

## View Movies logs
movies-logs:
	kubectl logs deployment/movies -n $(NAMESPACE)

## Open a shell inside a Pod
shell:
	@echo "1. List the Pods:"
	@echo "   kubectl get pods -n $(NAMESPACE)"
	@echo ""
	@echo "2. Open a shell:"
	@echo "   kubectl exec -it <pod-name> -n $(NAMESPACE) -- /bin/sh"

## Access the API locally
port-forward:
	kubectl port-forward service/api-service 8080:80 -n $(NAMESPACE)