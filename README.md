# k3s-gitops-lab

A local Kubernetes GitOps lab demonstrating automated application deployment, declarative infrastructure configuration, and end-to-end observability using k3s, Argo CD, Prometheus, Loki, Tempo, Grafana, and Grafana Alloy.

## Architecture

```text
Developer
   |
   v
GitHub Repository (main)
   |
   v
Argo CD — GitOps Reconciliation
   |
   +----------------------+----------------------+
   |                      |                      |
   v                      v                      v
  NOVA Store          Prometheus Stack      Logging Stack
  FastAPI API         Prometheus             Alloy -> Loki
   |                      |                      |
   +----------------------+----------------------+
                          |
                          v
                        Grafana
                          ^
                          |
                    Tempo Traces
                NOVA API -> Alloy -> Tempo
```

### Technology stack

| Component | Purpose |
|---|---|
| Docker Desktop | Local container runtime using WSL2 |
| k3d / k3s | Local Kubernetes cluster |
| Argo CD | GitOps-based application delivery and reconciliation |
| Helm | Installation and configuration of observability components |
| FastAPI | Sample NOVA Store API |
| Prometheus | Application and Kubernetes metrics collection |
| Grafana Alloy | Telemetry collection and forwarding |
| Loki | Centralized log storage and querying |
| Tempo | Distributed trace storage and querying |
| Grafana | Observability dashboards and exploration |

## Repository structure

```text
.
├── apps/
│   └── sample-api/
│       ├── app/
│       ├── k8s/
│       └── Dockerfile
├── bootstrap/
│   └── bootstrap.ps1
├── gitops/
│   ├── root-app.yaml
│   └── apps/
└── observability/
    └── values/
        ├── alloy.yaml
        ├── grafana.yaml
        ├── loki.yaml
        ├── prometheus.yaml
        └── tempo.yaml
```

## Prerequisites

The bootstrap workflow is designed for Windows with PowerShell and Docker Desktop using WSL2.

Install and configure:

- Docker Desktop, with its engine running.
- PowerShell.
- Git.
- k3d.
- kubectl.
- Helm.

Ensure Docker has sufficient CPU, memory, and disk capacity for the Kubernetes cluster and observability workloads.

## Getting started

Clone the repository:

```powershell
git clone https://github.com/vasitvajay/k3s-gitops-lab.git
Set-Location k3s-gitops-lab
```

Run the bootstrap script:

```powershell
.\bootstrap\bootstrap.ps1
```

The script automates local cluster setup, application image preparation, Argo CD installation, Grafana credential provisioning, and submission of the root GitOps Application.

The root Application discovers child applications under `gitops/apps`. Argo CD then reconciles their desired state from Git.

The bootstrap script is intended to support reruns. Review its output for errors before proceeding.

## Verify the deployment

### 1. Kubernetes resources

```powershell
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -A
```

Confirm that the node is Ready, the Argo CD Applications are Synced and Healthy, and application and observability pods are Running or otherwise in their expected healthy state.

### 2. NOVA Store API

Check the application service:

```powershell
kubectl get svc -n sample-api
kubectl port-forward -n sample-api svc/nova-store 8000:80
```

Keep the port-forward terminal open. In another PowerShell terminal, test the endpoints:

```powershell
Invoke-RestMethod http://localhost:8000/api/health
Invoke-RestMethod http://localhost:8000/api/products
Invoke-WebRequest -UseBasicParsing http://localhost:8000/metrics
```

Interactive API documentation is available at:

- Swagger UI: `http://localhost:8000/docs`
- OpenAPI schema: `http://localhost:8000/openapi.json`

The application exposes health, product, category, order, and Prometheus metrics endpoints.

### 3. Grafana

Forward the Grafana service:

```powershell
kubectl port-forward -n observability svc/grafana 3000:80
```

Open `http://localhost:3000`.

Retrieve the provisioned administrator password:

```powershell
$Password = kubectl get secret grafana-admin -n observability -o jsonpath="{.data.admin-password}"
[System.Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($Password)
)
```

Use the provisioned administrator username and the retrieved password to sign in. Keep credentials out of source control.

### 4. Prometheus

Forward the Prometheus service:

```powershell
kubectl port-forward -n observability svc/prometheus-server 9090:80
```

Open `http://localhost:9090` and query:

```promql
up
```

Check application request metrics:

```promql
nova_http_requests_total
```

Generate API requests before querying if you need fresh traffic.

### 5. Loki logs

Use Grafana Explore and select the Loki data source.

A basic LogQL query is:

```logql
{namespace="sample-api"}
```

If your labels differ, inspect the available labels in Grafana Explore and adapt the query.

### 6. Tempo traces

Use Grafana Explore and select Tempo. Search for traces from the `nova-api` service and open a trace to inspect its spans and timing.

Generate traffic against the API while testing. The application sends OpenTelemetry data through Alloy to Tempo.

The provisioned data sources are configured through `observability/values/grafana.yaml`.

## GitOps workflow

1. Modify application manifests, Helm values, or the root/child Application configuration.
2. Commit and push the changes to the tracked Git branch.
3. Allow Argo CD to detect the desired-state changes.
4. Verify synchronization and health:

```powershell
kubectl get applications -n argocd
kubectl get pods -A
```

The root Application uses automated synchronization with pruning and self-healing. Review changes carefully because pruning can remove resources no longer declared in Git.

## Troubleshooting

### Application is unavailable

```powershell
kubectl get pods -n sample-api
kubectl get svc -n sample-api
kubectl logs -n sample-api deployment/nova-store
kubectl describe pods -n sample-api
```

Use the actual deployment or pod name if it differs.

### An Argo CD Application is not healthy

```powershell
kubectl get applications -n argocd
kubectl describe application sample-api -n argocd
kubectl describe application observability -n argocd
```

Check synchronization errors, Helm rendering failures, missing resources, and pod events.

### Metrics are missing

```powershell
kubectl get svc -n observability
kubectl get pods -n observability
```

Verify the application's `/metrics` endpoint, Prometheus targets, and the scrape configuration.

### Logs or traces are missing

Inspect Alloy and the relevant backend:

```powershell
kubectl get pods -n observability
kubectl logs -n observability deployment/alloy
kubectl logs -n observability statefulset/tempo
kubectl logs -n observability statefulset/loki
```

If a resource uses a different workload type or name, retrieve its actual name with `kubectl get pods -n observability`.

Check the configured endpoints, receiver ports, labels, and time range in Grafana Explore.

## Cleanup

**Warning:** The following command deletes the local k3d cluster and its workloads.

First confirm the cluster name:

```powershell
k3d cluster list
```

If the cluster is named `devops-assessment`, delete it with:

```powershell
k3d cluster delete devops-assessment
```

Review the bootstrap script before using it to recreate the environment.

## Security and scope

This project is a local assessment lab, not a production-ready deployment. Production use would require appropriate authentication, TLS, secret management, persistent storage and backup policies, resource sizing, access controls, and operational alerting.

Never commit real credentials or sensitive configuration to Git.

## License

Add the license applicable to this repository if distribution or reuse requires one.
