# Docker sample guide

This project provides production-style Docker setups for **Next.js** (standalone and static export), following patterns from the [Next.js with-docker](https://github.com/vercel/next.js/tree/canary/examples/with-docker) and [with-docker-export-output](https://github.com/vercel/next.js/tree/canary/examples/with-docker-export-output) examples.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (with BuildKit)
- [Docker Compose](https://docs.docker.com/compose/) (v2+ with Compose Watch for dev)

## Dockerfiles overview

| File | Purpose | Output / Runtime | Port |
|------|---------|------------------|------|
| **Dockerfile** | Next.js **standalone** (Node server) | `.next/standalone` + `node server.js` | 3000 |
| **Dockerfile.dev** | Next.js **development** (HMR, Compose Watch) | dev server | 3000 |
| **Dockerfile.export** | Next.js **static export** (Nginx) | `out/` → Nginx | 8080 |
| **Dockerfile.nginx** | Next.js **static export** (Nginx, alt) | `out/` → Nginx | 8080 |
| **Dockerfile.serve** | Next.js **static export** (Node serve) | `out/` → serve | 8080 |

- **Standalone:** `next.config` uses `output: "standalone"` (default when `NEXT_OUTPUT` is unset).
- **Static export:** Dockerfile.export, Dockerfile.nginx, and Dockerfile.serve set `NEXT_OUTPUT=export`; Next.js produces `out/`.

All Dockerfiles support **npm**, **yarn**, and **pnpm** via lockfile detection (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`).

## Quick start with Compose

Run **one** of these at a time (port 8080 is shared by static-export services):

```bash
# Next.js standalone (production)
docker compose up nextjs-prod-standalone --build
# → http://localhost:3000

# Next.js development (with live sync)
docker compose watch nextjs-dev
# → http://localhost:3000

# Next.js static export (Nginx)
docker compose up nextjs-export --build
# → http://localhost:8080

# Next.js static export + Nginx (alt, same port)
docker compose up nextjs-prod-static-nginx --build
# → http://localhost:8080

# Next.js static export + Node serve (same port)
docker compose up nextjs-prod-static-serve --build
# → http://localhost:8080
```

One-off tasks (profile: tools):

```bash
docker compose --profile tools run --rm nextjs-test
docker compose --profile tools run --rm nextjs-lint
```

## Testing Kubernetes

The manifest `nextjs-sample-kubernetes.yaml` runs the Next.js standalone app in a Deployment with a NodePort Service (port **30001**).

**Prerequisites:** A running cluster (e.g. [Docker Desktop](https://docs.docker.com/desktop/kubernetes/) with Kubernetes enabled, or minikube/kind) and `kubectl` in your PATH.

**1. Build the image** (same image name as in the manifest):

```bash
docker build -t nextjs-sample:latest -f Dockerfile .
```

**2. Make the image available to the cluster**

- **Docker Desktop:** The image is already visible to the cluster; skip to step 3.
- **minikube:** `eval $(minikube docker-env)` then run the build above, or `minikube image load nextjs-sample:latest` after building.
- **kind:** `kind load docker-image nextjs-sample:latest` after building.

**3. Apply the manifest**

```bash
kubectl apply -f nextjs-sample-kubernetes.yaml
```

**4. Wait for the pod to be ready**

```bash
kubectl get pods -l app=nextjs-sample -w
```

Wait until the pod shows `Running` and `1/1` ready, then Ctrl+C.

**5. Hit the app**

- **Docker Desktop:** open **http://localhost:30001**
- **minikube:** `minikube service nextjs-sample-service --url` then open the URL, or use **http://\<minikube-ip\>:30001** (e.g. `minikube ip`).

**6. Sanity check**

```bash
kubectl get deployment nextjs-sample
kubectl get service nextjs-sample-service
kubectl logs -l app=nextjs-sample --tail=20
```

**Cleanup**

```bash
kubectl delete -f nextjs-sample-kubernetes.yaml
```

## Build and run without Compose

```bash
# Next.js standalone
docker build -t nextjs-sample:latest .
docker run -p 3000:3000 nextjs-sample:latest

# Next.js static export (Nginx)
docker build -f Dockerfile.export -t nextjs-export .
docker run -p 8080:8080 nextjs-export

# Next.js static export (Nginx, alt)
docker build -f Dockerfile.nginx -t static-nginx .
docker run -p 8080:8080 static-nginx

# Next.js static export (Node serve)
docker build -f Dockerfile.serve -t static-serve .
docker run -p 8080:8080 static-serve
```

## Project structure (Docker-related)

```
├── Dockerfile              # Next.js standalone
├── Dockerfile.dev          # Next.js development
├── Dockerfile.export       # Next.js static export → Nginx
├── Dockerfile.nginx        # Next.js static export → Nginx (alt)
├── Dockerfile.serve        # Next.js static export → Node serve
├── compose.yaml            # All services
├── nginx.conf              # Used by Dockerfile.export and Dockerfile.nginx
├── nextjs-sample-kubernetes.yaml
├── .dockerignore
└── README.Docker.md        # This guide
```

## Highlights (aligned with Vercel examples)

- **Multi-stage builds:** Dependencies → build → runtime (smaller images, clear layers).
- **BuildKit cache mounts:** npm/yarn/pnpm caches and, where applicable, `.next/cache` for faster rebuilds.
- **Lockfile-based installs:** `npm ci` / `yarn install --frozen-lockfile` / `pnpm install --frozen-lockfile` for reproducible builds.
- **Non-root user:** `node` or `nginx` in final stage.
- **Version maintenance:** `NODE_VERSION` and `NGINXINC_IMAGE_TAG` (or equivalent) are ARGs; keep them updated for security and compatibility.

## References

- [Next.js with-docker (standalone)](https://github.com/vercel/next.js/tree/canary/examples/with-docker)
- [Next.js with-docker-export-output (static export + Nginx)](https://github.com/vercel/next.js/tree/canary/examples/with-docker-export-output)
- [Docker Compose file watch](https://docs.docker.com/compose/file-watch/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
