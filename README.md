# k3s-gitops-lab

A local Kubernetes GitOps lab demonstrating automated application
delivery and end-to-end observability. The project deploys the NOVA
Store sample API to a local k3d/k3s cluster, uses Argo CD to reconcile
Kubernetes resources from Git, and collects metrics, logs, and traces
using Prometheus, Grafana Alloy, Loki, Tempo, and Grafana.

The lab is designed for a repeatable local assessment environment. It is
not intended to be a production-ready Kubernetes platform.

## Table of contents

-   [Architecture](#architecture)
-   [Technology stack](#technology-stack)
-   [Repository structure](#repository-structure)
-   [Prerequisites](#prerequisites)
-   [Quick start](#quick-start)
-   [Bootstrap behavior](#bootstrap-behavior)
-   [GitOps workflow](#gitops-workflow)
-   [Access the application and observability
    tools](#access-the-application-and-observability-tools)
-   [Validate telemetry](#validate-telemetry)
-   [NOVA Store API](#nova-store-api)
-   [Troubleshooting](#troubleshooting)
-   [Cleanup](#cleanup)
-   [Security and limitations](#security-and-limitations)
-   [Documentation](#documentation)

## Architecture

``` text
                         GitHub: main
                              |
                              v
                      Argo CD root Application
                              |
                  discovers gitops/apps recursively
                              |
             +----------------+----------------+
             |                                 |
             v                                 v
      NOVA Store API                    Observability apps
      FastAPI / Python                  Helm-managed resources
             |                                 |
      +------+----------------+----------------+
      |                       |                |
      | /metrics              | JSON stdout    | OTLP/HTTP
      v                       v                v
  Prometheus                Alloy <---------- NOVA Store
                                |                |
                                v                |
                              Loki               |
                                                 |
                                Alloy ----------+
                                  |
                                  | OTLP/gRPC
                                  v
                                Tempo

                  Grafana queries Prometheus, Loki, and Tempo
```

### Telemetry flow

-   **Metrics:** Prometheus scrapes the API's `/metrics` endpoint every
    15 seconds.
-   **Logs:** The API writes structured JSON events to standard output.
    Grafana Alloy discovers Kubernetes pod logs and forwards them to
    Loki.
-   **Traces:** The API uses OpenTelemetry instrumentation and sends
    telemetry to Alloy over OTLP/HTTP. Alloy forwards traces to Tempo.
-   **Exploration:** Grafana is provisioned with Prometheus, Loki, and
    Tempo data sources.

## Technology stack

  Component                   Purpose
  --------------------------- ----------------------------------------
  Docker Desktop with WSL 2   Local container runtime
  k3d / k3s                   Local Kubernetes cluster
  kubectl                     Kubernetes command-line administration
  Helm                        Chart packaging and configuration
  Argo CD                     GitOps reconciliation and deployment
  FastAPI                     NOVA Store sample API
  Prometheus                  Metrics collection and querying
  Grafana Alloy               Telemetry collection and forwarding
  Loki                        Log storage and querying
  Tempo                       Distributed trace storage and querying
  Grafana                     Metrics, logs, and trace exploration

## Repository structure

``` text
k3s-gitops-lab/
├── README.md
├── docs/
│   ├── ai-interaction-log.md
│   ├── api-docs.md
│   ├── bootstrap-guide.md
│   └── observability-stack.md
├── apps/
│   └── sample-api/
│       ├── app/
│       │   ├── main.py
│       │   └── static/
│       ├── k8s/
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       ├── Dockerfile
│       └── requirements.txt
├── bootstrap/
│   ├── bootstrap.ps1
│   └── install-argocd.ps1
├── gitops/
│   ├── root-app.yaml
│   └── apps/
│       ├── sample-api.yaml
│       └── observability.yaml
└── observability/
    ├── k8s/
    │   ├── alloy.yaml
    │   ├── grafana.yaml
    │   ├── loki.yaml
    │   ├── prometheus.yaml
    │   └── tempo.yaml
    └── values/
        ├── alloy.yaml
        ├── grafana.yaml
        ├── loki.yaml
        ├── prometheus.yaml
        └── tempo.yaml
```

## Prerequisites

The bootstrap workflow is intended for Windows with PowerShell and
Docker Desktop using the WSL 2 backend.

Install and verify:

-   Docker Desktop, with its Linux container engine running.
-   Git for Windows.
-   k3d.
-   kubectl.
-   Helm.
-   PowerShell.

The environment used during development included Windows 10 Home 64-bit,
Docker Desktop 29.8.2, WSL 2.5.10.0, Git 2.50.1, k3d v5.9.0, kubectl
v1.36.1, and Helm v4.3.0. These are the versions used during validation,
not necessarily strict minimum-version requirements.

Run the following in PowerShell:

PS : { docker info docker version git --version k3d version kubectl
version --client helm version kubectl config get-contexts k3d cluster
list }

Docker must be available before the bootstrap script is run. Allocate
enough CPU, memory, and disk capacity for Kubernetes, Argo CD, the
application, and observability workloads.

## Quick start

### 1. Clone the repository

PS : { git clone https://github.com/vasitvajay/k3s-gitops-lab.git
Set-Location .`\k3`{=tex}s-gitops-lab }

Verify the expected files:

PS : { Test-Path .`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1 Test-Path
.`\bootstrap`{=tex}`\install`{=tex}-argocd.ps1 Test-Path
.`\apps`{=tex}`\sample`{=tex}-api`\Dockerfile`{=tex} Test-Path
.`\gitops`{=tex}`\root`{=tex}-app.yaml }

Each command should return `True`.

### 2. Run the bootstrap script

The default configuration uses cluster name `devops-assessment` and host
port mapping `8080:80@loadbalancer`.

PS : { powershell.exe -NoProfile -ExecutionPolicy Bypass \` -File
".`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1" }

The execution-policy bypass applies only to that PowerShell process. If
your current PowerShell policy already permits the script, you can run
it directly:

PS : { .`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1 }

### 3. Use a separate cluster for isolated testing

If you want to keep an existing cluster untouched, select a separate
cluster name and host port:

PS : { powershell.exe -NoProfile -ExecutionPolicy Bypass
`-File ".\bootstrap\bootstrap.ps1"` -ClusterName
"devops-assessment-fresh" \` -HttpPortMapping "8081:80@loadbalancer" }

The script can reuse an existing cluster with the supplied name. It does
not delete or recreate that cluster automatically. An existing cluster's
port mapping is not changed by rerunning the script.

### 4. Wait for GitOps reconciliation

Bootstrap submits the root Argo CD Application. Child Applications and
workloads may need additional time to become healthy.

PS : { kubectl config current-context kubectl get nodes -o wide kubectl
get applications.argoproj.io -n argocd kubectl get pods -n argocd
kubectl get pods -n sample-api kubectl get pods -n observability kubectl
get pvc -n observability }

The expected Kubernetes context is `k3d-devops-assessment` for the
default cluster, or `k3d-<ClusterName>` for a custom cluster.
Applications should eventually report `Synced` and `Healthy`, and
workloads should reach their expected ready state.

## Bootstrap behavior

The bootstrap scripts automate the initial environment setup:

1.  Check required commands and Docker availability.
2.  Create the configured k3d cluster if it does not exist, or reuse it
    if it does.
3.  Select and verify the matching Kubernetes context.
4.  Wait for the Kubernetes node to become ready.
5.  Build the `nova-store:dev` container image.
6.  Import the image into the selected k3d cluster.
7.  Install the pinned Argo CD release and wait for key components.
8.  Ensure the observability namespace exists.
9.  Create the `grafana-admin` Secret only if it does not already exist.
10. Apply `gitops/root-app.yaml` and wait for the root Application to be
    registered.

The NOVA Store Deployment uses `imagePullPolicy: Never`, so the locally
built image must be imported into the same k3d cluster that runs the
workload.

The bootstrap script's success message means the root Application has
been registered. It does not guarantee that every child Application has
already finished reconciling.

## GitOps workflow

The root Application in `gitops/root-app.yaml` tracks the `main` branch
of this repository and recursively watches `gitops/apps`.

The child Applications manage the sample API and observability
components, including Alloy, Grafana, Loki, Prometheus, and Tempo. The
observability Application definitions in `observability/k8s/` use
version-pinned Helm charts and values files under
`observability/values/`.

Automated synchronization, pruning, and self-healing are enabled.
Pruning can remove resources that are no longer declared in Git, so
review manifest changes carefully.

**Important:** Argo CD reconciles the remote Git revision configured in
the Application. Local changes that have not been pushed to the tracked
branch are not automatically deployed. The local image build/import is
also separate from manifest synchronization.

After bootstrap, use Git to change the desired state. Do not manually
apply application or observability manifests as a substitute for GitOps
reconciliation.

## Access the application and observability tools

Use `kubectl port-forward` to access services locally. Each port-forward
command should run in its own PowerShell terminal and remain running
while you use that service.

### Port mapping versus port-forwarding

The k3d host port mapping configured during cluster creation exposes a
port on the k3d load balancer. For example, `8081:80@loadbalancer` maps
host port 8081 to port 80 on the k3d load-balancer container. Access
through that path depends on the configured ingress and routing
resources.

`kubectl port-forward` creates a temporary connection to a specified
Kubernetes Service or Pod. It does not require ingress routing and ends
when the command stops.

### NOVA Store API

PS : { kubectl port-forward -n sample-api svc/nova-store 18000:80 }

Open:

-   Storefront: http://127.0.0.1:18000
-   Health endpoint: http://127.0.0.1:18000/api/health
-   Interactive API documentation: http://127.0.0.1:18000/docs

Test the API in a second terminal:

PS : { Invoke-RestMethod "http://127.0.0.1:18000/api/health"
Invoke-RestMethod "http://127.0.0.1:18000/api/categories"
Invoke-RestMethod "http://127.0.0.1:18000/api/products" }

Expected health response:

JSON : { { "status": "healthy", "service": "nova-api" } }

### Grafana

PS : { kubectl port-forward -n observability svc/grafana 13000:80 }

Open http://127.0.0.1:13000. The administrator username is `admin`.

Retrieve the provisioned password without committing it to Git:

PS : { \$Password = kubectl get secret grafana-admin \` -n observability
-o jsonpath="{.data.admin-password}"

if (\$LASTEXITCODE -ne 0 -or -not \$Password) { throw "Unable to
retrieve the Grafana admin password." }

    [Convert]::FromBase64String($Password)

) }

Treat the password as a secret. Do not include it in logs,
documentation, screenshots, or commits.

### Prometheus

PS : { kubectl port-forward -n observability svc/prometheus-server
19090:80 }

Open http://127.0.0.1:19090.

Useful PromQL queries:

PromQL : { up }

PromQL : { nova_http_requests_total }

### Loki

PS : { kubectl port-forward -n observability svc/loki 13100:3100 }

The local endpoint is http://127.0.0.1:13100. The usual workflow is to
query Loki through Grafana Explore.

### Tempo

PS : { kubectl port-forward -n observability svc/tempo 13200:3200 }

The local endpoint is http://127.0.0.1:13200. Use Grafana Explore to
search for traces from service `nova-api`.

## Validate telemetry

Generate test traffic while the API port-forward is running:

PS : { 1..10 \| ForEach-Object { Invoke-RestMethod
"http://127.0.0.1:18000/api/health" }

Invoke-RestMethod \`
"http://127.0.0.1:18000/api/products?category=Audio" }

Then validate the telemetry:

-   **Metrics:** In Prometheus, query `up` and
    `nova_http_requests_total`. The API scrape target should be up.
    Allow at least one 15-second scrape interval for new metrics to
    appear.
-   **Logs:** In Grafana Explore, select Loki and run
    `{namespace="sample-api"}`. Look for JSON request events such as
    `http_request`.
-   **Traces:** In Grafana Explore, select Tempo and search for the
    `nova-api` service. Generate new traffic if no recent traces are
    available.

The application exposes request counters and request-duration
histograms, emits structured JSON logs to standard output, and exports
traces through Alloy to Tempo.

## NOVA Store API

The FastAPI application includes endpoints for health checks,
categories, products, and orders.

  ------------------------------------------------------------------------------
  Method                  Endpoint                       Purpose
  ----------------------- ------------------------------ -----------------------
  GET                     `/api/health`                  Application health

  GET                     `/api/categories`              List product categories

  GET                     `/api/products`                List products; supports
                                                         an optional category
                                                         filter

  GET                     `/api/products/{product_id}`   Retrieve one product

  POST                    `/api/orders`                  Create an in-memory
                                                         order

  GET                     `/api/orders/{order_id}`       Retrieve an order

  GET                     `/metrics`                     Prometheus metrics

  GET                     `/docs`                        Interactive OpenAPI
                                                         documentation
  ------------------------------------------------------------------------------

Orders are stored in application memory and are not persistent across
restarts. Invalid request bodies can return `422`; unknown products and
orders return `404`.

For full request/response examples and error cases, see [API
Documentation](docs/api-docs.md).

## Troubleshooting

### Docker is unavailable

Start Docker Desktop, wait for the Linux container engine to become
ready, and run `docker info` again.

### The wrong cluster is selected

PS : { kubectl config current-context kubectl config get-contexts k3d
cluster list }

Confirm that the active context matches the cluster passed to the
bootstrap script.

### The API cannot find its image

PS : { kubectl get pods -n sample-api kubectl describe deployment
nova-store -n sample-api }

Verify that `nova-store:dev` was built and imported into the same k3d
cluster selected by kubectl.

### An Argo CD Application is not healthy

PS : { kubectl get applications.argoproj.io -n argocd kubectl get pods
-A kubectl get events -A --sort-by=.metadata.creationTimestamp }

Inspect Application status, pod events, failed probes, image errors,
storage provisioning, and Helm reconciliation errors.

### Port-forwarding fails

PS : { kubectl get svc -n sample-api kubectl get endpoints -n sample-api
kubectl get pods -n sample-api kubectl get svc -n observability }

Check that the Service exists, its endpoints are available, the target
pod is ready, and the local port is not already occupied. Stop a
previous port-forward with `Ctrl+C` before restarting it.

### Telemetry is missing

Generate fresh API traffic. Then verify the API and Alloy pods,
Prometheus target status, Loki and Tempo readiness, Grafana's selected
data source, and the selected time range.

For more detailed setup and troubleshooting steps, see the [Bootstrap
Guide](docs/bootstrap-guide.md) and [Observability Stack
Documentation](docs/observability-stack.md).

## Cleanup

**Warning:** Deleting a k3d cluster removes its Kubernetes workloads and
cluster-local data.

List clusters and verify the exact target before deleting anything:

PS : { k3d cluster list kubectl config get-contexts }

If you created a disposable test cluster named `devops-assessment-fresh`
and no longer need it:

PS : { k3d cluster delete devops-assessment-fresh }

Do not run the delete command against `devops-assessment` unless you
explicitly intend to remove that cluster.

## Security and limitations

This is a local assessment lab, not a highly available production
deployment.

-   Loki and Tempo use local persistence for this lab; this is not a
    production-grade storage or disaster-recovery design.
-   The cluster is local and single-node.
-   Orders are stored in memory and are not persistent.
-   Protect the Grafana administrator password and never commit real
    credentials.
-   Review Argo CD pruning and self-healing behavior before changing
    desired-state manifests.
-   Production use would require appropriate authentication, TLS, secret
    management, backups, resource sizing, access controls, monitoring,
    and operational alerting.

## Documentation

-   [Bootstrap Guide](docs/bootstrap-guide.md) --- prerequisites,
    clean-start checklist, configuration, bootstrap execution,
    verification, port mapping versus port-forwarding, and
    troubleshooting.
-   [API Documentation](docs/api-docs.md) --- endpoints,
    request/response examples, validation, errors, and metrics.
-   [Observability Stack Documentation](docs/observability-stack.md) ---
    component versions, telemetry flow, metrics, logs, traces, and
    verification.
-   [AI Interaction Log](docs/ai-interaction-log.md) --- curated
    highlights of AI-assisted implementation, debugging, and validation.
