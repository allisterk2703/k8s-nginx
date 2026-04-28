.PHONY: help build run stop delete apply deploy up restart status pods endpoints logs url down clean

MAKEFLAGS += --silent

IMAGE      ?= nginx-image:latest
CONTAINER  ?= nginx-container
NAMESPACE  ?= nginx-namespace
DEPLOY     ?= nginx-deployment
SERVICE    ?= nginx-service
APP_LABEL  ?= nginx-app
MANIFESTS  ?= k8s/
HOST_PORT  ?= 8080

help: ## Show this help message
	echo "Available commands:"
	grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  🔹 \033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ============================================================
# Docker
# ============================================================

build: ## [docker] Build the Docker image ($(IMAGE))
	docker build -t $(IMAGE) .

run: build ## [docker] Run the image standalone, mapping container :80 -> host :$(HOST_PORT)
	docker run --rm -d --name $(CONTAINER) -p $(HOST_PORT):80 $(IMAGE)
	echo "→ nginx available at http://localhost:$(HOST_PORT)"

stop: ## [docker] Stop the standalone container started by "run"
	-docker stop $(CONTAINER)

delete: stop ## [docker] Remove the local Docker image ($(IMAGE))
	-docker rmi $(IMAGE)

# ============================================================
# Kubernetes
# ============================================================

apply: ## [k8s] Apply all manifests in $(MANIFESTS)
	kubectl apply -f $(MANIFESTS)

deploy: build apply restart url ## [k8s] Build the image, apply manifests, restart pods, and print the URL

up: deploy ## [k8s] Alias for "deploy"

restart: ## [k8s] Force a rolling restart of the Deployment
	kubectl -n $(NAMESPACE) rollout restart deploy/$(DEPLOY)
	kubectl -n $(NAMESPACE) rollout status deploy/$(DEPLOY) --timeout=60s

status: ## [k8s] Show pods and services in the namespace
	kubectl -n $(NAMESPACE) get pods,svc -o wide

pods: ## [k8s] Show pods in the namespace with their node and IP
	kubectl -n $(NAMESPACE) get pods -o wide

endpoints: ## [k8s] Show EndpointSlices backing $(SERVICE)
	kubectl -n $(NAMESPACE) get endpointslices -l kubernetes.io/service-name=$(SERVICE)

logs: ## [k8s] Tail nginx logs from all pods
	kubectl -n $(NAMESPACE) logs -l app=$(APP_LABEL) --tail=100 -f

url: ## [k8s] Print the Service URL (LoadBalancer IP if any, otherwise ClusterIP / DNS)
	LB=$$(kubectl -n $(NAMESPACE) get svc $(SERVICE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	CIP=$$(kubectl -n $(NAMESPACE) get svc $(SERVICE) -o jsonpath='{.spec.clusterIP}'); \
	if [ -n "$$LB" ]; then echo "http://$$LB/"; else echo "http://$$CIP/   (ClusterIP — reachable from host on OrbStack)"; fi
	echo "http://$(SERVICE).$(NAMESPACE).svc.cluster.local/   (OrbStack DNS)"

down: ## [k8s] Delete the namespace and all its resources
	kubectl delete namespace $(NAMESPACE) --ignore-not-found
