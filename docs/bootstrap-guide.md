# Bootstrap Guide --- NOVA Store GitOps Lab## 1. Purpose

This guide explains how to set up the local Kubernetes environment,
install Argo CD, deploy NOVA Store and the observability stack, and
access the application and monitoring interfaces.

The lab uses Docker Desktop, k3d/k3s, Argo CD, and Kubernetes manifests
managed through GitOps. The bootstrap script performs the initial setup;
Argo CD reconciles the application and observability resources from the
Git repository.

The intended workflow is:

1\. Install and verify the prerequisites.

2\. Clone the repository.

3\. Run the bootstrap script.

4\. Wait for Argo CD to reconcile the applications.

5\. Verify application and observability health.

6\. Access the API and monitoring interfaces.

7\. Generate test traffic and verify telemetry. \## 2. Prerequisites###
Validated development environment The following environment was used
during development and validation:

| Component \| Version or configuration \|

\|---\|---\|

| Operating system \| Windows 10 Home, 64-bit \|

| Container runtime \| Docker Desktop 29.8.2 \|

| Linux integration \| WSL 2 \|

| WSL \| 2.5.10.0 \|

| Git \| 2.50.1 \|

| k3d \| v5.9.0 \|

| kubectl \| v1.36.1 \|

| Helm \| v4.3.0 \|

The bootstrap script explicitly checks for Docker, k3d, and kubectl. Git
is needed to clone the repository. Helm is included in the development
environment and is useful for inspecting the chart-based observability
configuration.

### Clean-Start Checklist

Use this checklist when setting up the assessment from a fresh clone or
validating the bootstrap process from scratch. A clean start does not
require deleting your existing cluster.

#### Before you begin

-   [ ] Docker Desktop is running and its Linux container engine is
    available.

-   [ ] docker, k3d, kubectl, helm, and git are available in PowerShell.

-   [ ] The repository has been cloned and you are in its root
    directory.

-   [ ] The bootstrap scripts and GitOps manifests exist.

-   [ ] The Docker image build context at apps`\sample`{=tex}-api is
    present.

-   [ ] You have checked the current Kubernetes contexts and existing
    k3d clusters.

-   [ ] You have selected a cluster name and a host port that do not
    conflict with another local environment.

Check your environment:

docker info

docker version

k3d version

kubectl version --client

helm version

git --version

kubectl config get-contexts

k3d cluster list

#### Choose the cluster deliberately

For a normal setup, the script defaults to the devops-assessment cluster
and maps host port 8080 to the cluster's HTTP entry point.

For an isolated test, use a separate cluster name and host port so that
your existing cluster remains untouched:

.`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1 \`

  -ClusterName "devops-assessment-fresh" \`

  -HttpPortMapping "8081:80@loadbalancer"

Before running the command, verify that the selected cluster and port
are appropriate for your environment. The bootstrap script can reuse a
cluster with the specified name; it does not mean that the cluster is a
brand-new environment.

#### After bootstrap

-   [ ] The expected Kubernetes context is selected.

-   [ ] Kubernetes nodes report Ready.

-   [ ] The Argo CD root application is registered.

-   [ ] Argo CD reports the expected applications as Synced and Healthy.

-   [ ] The NOVA Store API pod is running and ready.

-   [ ] Grafana, Prometheus, Loki, and Tempo workloads are ready.

-   [ ] The API health endpoint responds successfully.

-   [ ] Prometheus reports the API scrape target as up.

-   [ ] API request logs are visible in Loki.

-   [ ] API traces are available in Tempo after generating traffic.

Useful verification commands:

kubectl config current-context

kubectl get nodes

kubectl get applications -n argocd

kubectl get pods -A

kubectl get svc -A

Check the API directly through a local port-forward:

kubectl port-forward -n sample-api svc/nova-store 8000:80

In another PowerShell window:

Invoke-RestMethod http://localhost:8000/api/health

Expected response:

{

  "status": "healthy",

  "service": "nova-api"

}

#### Clean up safely

Do not delete an existing cluster just to repeat the setup. If you
created a dedicated test cluster and have finished testing, verify its
name before removing it:

k3d cluster list

kubectl config get-contexts

Only remove the disposable test cluster when you are certain it is the
intended target:

k3d cluster delete devops-assessment-fresh

Replace the example name if your test cluster uses a different name. Do
not run this command against the original devops-assessment cluster
unless you explicitly intend to delete it. \### Required software
Install the following tools and ensure they are available in your
PowerShell session:

\- Docker Desktop, configured to use its WSL 2 backend.

\- Git for Windows.

\- k3d.

\- kubectl.

\- Helm.

Start Docker Desktop before running the bootstrap script. \### Verify
the prerequisites Open PowerShell and run:

PS : {

docker info

k3d version

kubectl version --client

git --version

helm version

}

Confirm that Docker responds successfully and that each command is
available. If a command is not recognized, install the corresponding
tool or correct the `PATH` configuration before continuing.

The cluster requires sufficient CPU, memory, and disk space for
Kubernetes, Argo CD, the API, and the observability workloads. \## 3.
Clone the repository Clone the repository and enter its directory:

PS : {

git clone https://github.com/vasitvajay/k3s-gitops-lab.git

Set-Location .`\k3`{=tex}s-gitops-lab

}

Check that the expected files exist:

PS : {

Test-Path .`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1

Test-Path .`\bootstrap`{=tex}`\install`{=tex}-argocd.ps1

Test-Path .`\apps`{=tex}`\sample`{=tex}-api`\Dockerfile`{=tex}

Test-Path .`\gitops`{=tex}`\root`{=tex}-app.yaml

}

Each command should return `True`.

Before execution, inspect `bootstrap\bootstrap.ps1` and
`bootstrap\install-argocd.ps1` to confirm that the submitted revisions
contain the expected context-selection and namespace-existence fixes.
\## 4. Bootstrap configuration The bootstrap script supports two
parameters:

| Parameter \| Default \| Purpose \|

\|---\|---\|---\|

| `ClusterName` \| `devops-assessment` \| Name of the k3d cluster to
  create or reuse \|

| `HttpPortMapping` \| `8080:80@loadbalancer` \| Maps host port 8080 to
  port 80 on the k3d load balancer \|

The default cluster context is `k3d-devops-assessment`.

If port 8080 is already occupied, choose another available host port.
For example, to use port 8081 and a separate cluster:

PS : {

powershell.exe -NoProfile -ExecutionPolicy Bypass \`

    -File ".`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1" \`

    -ClusterName "devops-assessment-fresh" \`

    -HttpPortMapping "8081:80@loadbalancer"

}

The isolated validation environment used this cluster name and port
mapping to avoid intentionally targeting the original
`devops-assessment` cluster.

**\*\*Important:\*\*** An existing cluster with the specified name is
reused. The bootstrap script does not automatically replace it or change
its existing port mapping. Choose the cluster name deliberately. \## 5.
Run the bootstrap script From the repository root, execute:

PS : {

powershell.exe -NoProfile -ExecutionPolicy Bypass \`

    -File ".`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1"

}

The execution-policy bypass applies to this PowerShell child process
only. It does not change the machine-wide execution policy.

If you have already configured PowerShell to permit the script to run,
you can invoke it directly:

PS : {

.`\bootstrap`{=tex}`\bootstrap`{=tex}.ps1

}

Watch the output for errors. Do not proceed until the script reports
that bootstrap has completed. \### What the bootstrap script does The
script performs the following operations in sequence:

1\. **\*\*Checks prerequisites.\*\*** Verifies that Docker, k3d, and
kubectl are available and that Docker is responding.

2\. **\*\*Checks the cluster.\*\*** Lists existing k3d clusters and
determines whether the configured cluster already exists.

3\. **\*\*Creates or reuses the cluster.\*\*** Creates a single-server
k3d cluster when necessary, or reuses the cluster with the configured
name.

4\. **\*\*Selects the Kubernetes context.\*\*** Switches to
`k3d-<ClusterName>` and verifies that it is the active context.

5\. **\*\*Waits for Kubernetes readiness.\*\*** Waits for the node to
become Ready and displays node information.

6\. **\*\*Builds the application image.\*\*** Builds `nova-store:dev`
from `apps\sample-api`.

7\. **\*\*Imports the image.\*\*** Imports `nova-store:dev` into the
selected k3d cluster. This is necessary because the Kubernetes
Deployment uses `imagePullPolicy: Never`.

8\. **\*\*Installs Argo CD.\*\*** Runs `bootstrap\install-argocd.ps1`,
which installs the pinned Argo CD release, v3.5.5, and waits for key
components to become ready.

9\. **\*\*Prepares Grafana credentials.\*\*** Ensures that the
`observability` namespace exists and creates the `grafana-admin` Secret
if it is absent. Existing credentials are preserved on reruns.

10\. **\*\*Applies the root Application.\*\*** Applies
`gitops\root-app.yaml` and waits for the `root-app` Application to be
registered.

The script's final success message means the root Application has been
submitted and registered. Argo CD may still need time to reconcile the
child Applications and wait for workloads to become healthy. \## 6.
Bootstrap implementation detail: namespace creation The Argo CD
installer must handle a namespace that does not yet exist.

The corrected namespace check uses `--ignore-not-found` so that a
missing namespace can be distinguished from an actual kubectl failure:

PS : {

\$NamespaceExists = kubectl get namespace \$Namespace \`

    --ignore-not-found -o name 2\>\$null

if (\$LASTEXITCODE -ne 0) {

    throw "Failed to check whether namespace '\$Namespace' exists."

}

if (-not \$NamespaceExists) {

    kubectl create namespace \$Namespace

    if (\$LASTEXITCODE -ne 0) {

        throw "Failed to create namespace '\$Namespace'."

    }

}

}

Without this handling, the original existence check could terminate the
script under `$ErrorActionPreference = "Stop"` when Kubernetes returned
the expected `NotFound` response.

The corresponding fix should be present in the submitted
`bootstrap\install-argocd.ps1`. \## 7. How GitOps deployment works The
root Application is defined in `gitops\root-app.yaml`. It points to the
GitHub repository:

`https\://github.com/vasitvajay/k3s-gitops-lab.git`

It tracks the `main` branch and watches the `gitops/apps` directory
recursively.

The root Application discovers child Applications, including:

\- `sample-api`

\- `observability`

\- `alloy`

\- `grafana`

\- `loki`

\- `prometheus`

\- `tempo`

The API and observability resources are then reconciled by Argo CD
according to their Application definitions and referenced configuration.

The root Application enables automated synchronization, pruning, and
self-healing. Pruning can remove resources no longer declared in the
desired state, so changes to manifests should be reviewed carefully.

**\*\*Important:\*\*** Argo CD reads the configured remote Git branch.
Local changes that have not been pushed to that branch are not
automatically included in GitOps reconciliation. The bootstrap script
also builds and imports the API image locally; this is separate from
Argo CD's manifest synchronization. \## 8. Verify the cluster and
applications Run the following commands after bootstrap:

PS : {

kubectl config get-contexts

kubectl config current-context

kubectl get nodes -o wide

kubectl get applications.argoproj.io -n argocd

kubectl get pods -n argocd

kubectl get pods -n sample-api

kubectl get pods -n observability

kubectl get pvc -n observability

}

### Expected results

\- The active context should match the intended cluster.

\- The Kubernetes node should be `Ready`.

\- Argo CD Applications should eventually become `Synced` and `Healthy`.

\- The `nova-store` pod should become Ready.

\- Observability components should reach their expected ready state.

\- PVCs should bind where persistent storage is configured.

A workload can remain `Progressing` during initial chart installation or
volume provisioning. Inspect its events and logs before treating a
temporary startup state as a permanent failure. \### Previously observed
validation results During isolated validation, all eight Argo CD
Applications eventually reached `Synced` and `Healthy`:

`root-app`, `sample-api`, `observability`, `alloy`, `grafana`, `loki`,
`prometheus`, and `tempo`.

The NOVA Store pod reached `1/1 Running`, and the API and telemetry
backends were subsequently tested. \## 9. Access the API and
observability interfaces The following commands create local
port-forwards. Run each in its own PowerShell terminal and leave the
terminal open while using the corresponding interface. \### NOVA Store
API PS : {

kubectl port-forward -n sample-api svc/nova-store 18000:80

}

Open:

\- Storefront: <http://127.0.0.1:18000>

\- Health endpoint: <http://127.0.0.1:18000/api/health>

\- Interactive API documentation: <http://127.0.0.1:18000/docs>

Test the API from another terminal:

PS : {

Invoke-RestMethod "http://127.0.0.1:18000/api/health"

Invoke-RestMethod "http://127.0.0.1:18000/api/categories"

Invoke-RestMethod "http://127.0.0.1:18000/api/products"

}

The health endpoint should return a healthy status when the application
is operational. \### Grafana PS : {

kubectl port-forward -n observability svc/grafana 13000:80

}

Open <http://127.0.0.1:13000>.

The administrator username is `admin`. Retrieve the provisioned password
without placing it in source control:

PS : {

\$Password = kubectl get secret grafana-admin \`

    -n observability -o jsonpath="{.data.admin-password}"

if (\$LASTEXITCODE -ne 0 -or -not \$Password) {

    throw "Unable to retrieve the Grafana admin password."

}

    \[Convert\]::FromBase64String(\$Password)

)

}

Treat the resulting password as a secret. Do not paste it into logs,
documentation, or Git commits. \### Prometheus PS : {

kubectl port-forward -n observability svc/prometheus-server 19090:80

}

Open <http://127.0.0.1:19090>.

Try the following PromQL queries:

PromQL : {

up

}

PromQL : {

nova_http_requests_total

}

### Loki

PS : {

kubectl port-forward -n observability svc/loki 13100:3100

}

The local Loki endpoint is `http\://127.0.0.1:13100`. Logs can also be
explored through Grafana using the provisioned Loki data source. \###
Tempo PS : {

kubectl port-forward -n observability svc/tempo 13200:3200

}

The local Tempo query endpoint is `http\://127.0.0.1:13200`. For the
normal workflow, use Grafana Explore and search for traces from service
`nova-api`. \## 10. Generate traffic and verify telemetry With the API
port-forward running, send several requests:

PS : {

1..10 \| ForEach-Object {

    Invoke-RestMethod "http://127.0.0.1:18000/api/health"

}

Invoke-RestMethod \`

    "http://127.0.0.1:18000/api/products?category=Audio"

}

Then verify the telemetry:

\- **\*\*Prometheus:\*\*** Query `nova_http_requests_total` and confirm
that the API scrape target is up.

\- **\*\*Loki:\*\*** In Grafana Explore, select Loki and run
`{namespace="sample-api"}`.

\- **\*\*Tempo:\*\*** In Grafana Explore, select Tempo and search for
the `nova-api` service.

The application exposes request counters and latency histograms, writes
structured request logs to standard output, and exports traces through
Grafana Alloy to Tempo. \## 11. Troubleshooting### PowerShell refuses to
run the script Use the process-scoped invocation described in Section 5.
Confirm that the required script path exists and inspect the error
before retrying. \### Docker is unavailable Start Docker Desktop and
wait until the engine is ready. Run `docker info` again before
restarting bootstrap. \### The wrong Kubernetes cluster is selected
Check the active context:

PS : {

kubectl config current-context

kubectl config get-contexts

k3d cluster list

}

Use the context that matches the intended cluster. The bootstrap script
should also select and verify its configured context automatically. \###
Namespace creation fails Confirm that the submitted `install-argocd.ps1`
uses `kubectl get namespace --ignore-not-found -o name` and checks
`$LASTEXITCODE` before creating the namespace. \### The API pod cannot
find its image Check the pod events and ensure that the image was built
and imported into the same cluster that is currently selected:

PS : {

kubectl config current-context

kubectl get pods -n sample-api

kubectl describe deployment nova-store -n sample-api

}

The Deployment uses `image: nova-store:dev` and
`imagePullPolicy: Never`. Importing the image into a different k3d
cluster will not make it available to the intended workload. \### Argo
CD Applications remain Progressing or Degraded Inspect the Application
status, pod events, and persistent volumes:

PS : {

kubectl get applications.argoproj.io -n argocd

kubectl get pods -A

kubectl get pvc -n observability

kubectl get events -A --sort-by=.metadata.creationTimestamp

}

Look for image errors, failed probes, scheduling issues, storage
provisioning failures, or Helm reconciliation errors. \###
Port-forwarding fails Verify the Kubernetes context, service name,
service endpoints, and pod readiness:

PS : {

kubectl get svc -n sample-api

kubectl get endpoints -n sample-api

kubectl get pods -n sample-api

kubectl get svc -n observability

}

Ensure the local port is not already occupied. Stop the affected
port-forward with `Ctrl+C` before starting it again. \### Metrics, logs,
or traces are missing Generate fresh API traffic first. Then verify the
Prometheus target, Alloy pod readiness, and Loki and Tempo readiness.
Check Grafana's selected data source and time range, as well as the
relevant backend and collector logs. \## 12. Safe Cleanup
**\*\*Warning:\*\*** Deleting a k3d cluster removes its Kubernetes
workloads and cluster-local data.

First inspect the available clusters:

PS : {

k3d cluster list

}

If the isolated test cluster is no longer required and you have
confirmed its identity, remove only that cluster:

PS : {

k3d cluster delete devops-assessment-fresh

}

Do not run this command against `devops-assessment` unless you
explicitly intend to remove the original cluster. \## 13. Security and
Scope This is a local assessment lab, not a production-ready deployment.

\- Keep the Grafana administrator password out of Git and shared logs.

\- Review Argo CD pruning and self-healing behavior before changing
desired-state manifests.

\- Orders are held in application memory and are not persistent.

\- Use appropriate authentication, TLS, secret management, backups,
access controls, and operational alerting before adapting the lab for
production use.
