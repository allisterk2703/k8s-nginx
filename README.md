# k8s-nginx

A minimal example of running a custom nginx server on a local Kubernetes cluster (OrbStack). The HTML page is baked into a custom Docker image, the image is deployed via a Kubernetes `Deployment`, and the service is exposed to the host through a `LoadBalancer`.

## Layout

```
.
├── Dockerfile          # Builds the custom nginx image (FROM nginx:stable-alpine)
├── index.html          # The page served by nginx
├── Makefile            # Convenience targets (build, deploy, status, ...)
├── README.md
└── k8s/                # Kubernetes manifests, applied in numeric order
    ├── 01-namespace.yaml
    ├── 02-deployment.yaml
    └── 03-service.yaml
```

## Requirements

You need **either**:

- [OrbStack](https://orbstack.dev/) — recommended, as it bundles both Docker
  and a local Kubernetes cluster, and automatically shares locally-built
  Docker images with the cluster (no remote registry needed).

**or** the following combination:

- A local Kubernetes cluster (e.g. [minikube](https://minikube.sigs.k8s.io/),
  [k3s](https://k3s.io/), or [kind](https://kind.sigs.k8s.io/)) with
  `kubectl` pointed at it.
- A Docker engine (e.g. [Docker Desktop](https://www.docker.com/products/docker-desktop/))
  to build the image locally.

> ⚠️ With minikube/kind, you must load the locally-built image into the
> cluster manually (`minikube image load nginx-image:latest` or
> `kind load docker-image nginx-image:latest`), because `imagePullPolicy: Never`
> prevents Kubernetes from pulling it from any remote registry.

## Quick start

```bash
make deploy   # build the image, apply manifests, roll out, and print the URL
```

## How it works

0. `Dockerfile` copies `index.html` into the default nginx web root and
   produces the image `k8s-nginx:latest`.
1. `k8s/01-namespace.yaml` creates the `k8s-nginx` namespace so every
   resource lives in an isolated scope.
2. `k8s/02-deployment.yaml` ensures that 2 pods are running, each containing an `nginx-container` based on the `nginx-image:latest` image. It exposes port 80 and defines specific CPU and memory resources (both requests and limits). Finally, the pods are labeled with `app: nginx-app` to allow them to be targeted by other resources, such as a Service.
3. `k8s/03-service.yaml` asks OrbStack to provision a `LoadBalancer`. The private IP address of the load balancer is returned by OrbStack and registered on the Service; it acts as the stable entry point that routes incoming traffic on port 80 to the pods labeled `app: nginx-app`, balancing requests across them.
