# Bootstrap the local k3s cluster and install Argo CD.
# Prerequisites: Docker Desktop, k3d, kubectl.
# Safe to rerun: an existing cluster and Grafana credentials are reused.

$ErrorActionPreference = "Stop"

$ClusterName = "devops-assessment"
$ArgoCDScript = Join-Path $PSScriptRoot "install-argocd.ps1"

function Assert-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install it and try again."
    }
}

function Invoke-Kubectl {
    param([string[]]$Arguments)

    & kubectl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl failed: $($Arguments -join ' ')"
    }
}

Write-Host "`n=== Checking prerequisites ===" -ForegroundColor Cyan

Assert-Command "docker"
Assert-Command "k3d"
Assert-Command "kubectl"

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker is unavailable. Start Docker Desktop and retry."
}

Write-Host "Docker is available."
Write-Host "k3d version: $(k3d version)"
Write-Host "kubectl version:"
Invoke-Kubectl @("version", "--client")

Write-Host "`n=== Checking cluster ===" -ForegroundColor Cyan

$ClusterExists = $false
$ClusterList = @(k3d cluster list -o json | ConvertFrom-Json)

if ($LASTEXITCODE -ne 0) {
    throw "Unable to list k3d clusters."
}

foreach ($Cluster in $ClusterList) {
    if ($Cluster.name -eq $ClusterName) {
        $ClusterExists = $true
        break
    }
}

if (-not $ClusterExists) {
    Write-Host "Creating k3d cluster '$ClusterName'..."

    k3d cluster create $ClusterName `
        --servers 1 `
        --agents 0 `
        --port "8080:80@loadbalancer" `
        --wait

    if ($LASTEXITCODE -ne 0) {
        throw "Cluster creation failed."
    }
}
else {
    Write-Host "Cluster '$ClusterName' already exists; reusing it."
}

Write-Host "`n=== Waiting for Kubernetes node ===" -ForegroundColor Cyan

Invoke-Kubectl @("wait", "--for=condition=Ready", "nodes", "--all", "--timeout=180s")
Invoke-Kubectl @("get", "nodes", "-o", "wide")

$RepoRoot = Split-Path $PSScriptRoot -Parent
$DockerfileContext = Join-Path $RepoRoot "apps\sample-api"

Write-Host "`n=== Building NOVA Store image ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $DockerfileContext "Dockerfile"))) {
    throw "NOVA Store Dockerfile not found: $DockerfileContext"
}

docker build -t nova-store:dev $DockerfileContext

if ($LASTEXITCODE -ne 0) {
    throw "NOVA Store Docker image build failed."
}

Write-Host "`n=== Importing NOVA Store image into k3d ===" -ForegroundColor Cyan

k3d image import nova-store:dev --cluster $ClusterName

if ($LASTEXITCODE -ne 0) {
    throw "NOVA Store image import failed."
}

Write-Host "`n=== Installing Argo CD ===" -ForegroundColor Cyan

if (-not (Test-Path $ArgoCDScript)) {
    throw "Argo CD installation script not found: $ArgoCDScript"
}

& $ArgoCDScript

if ($LASTEXITCODE -ne 0) {
    throw "Argo CD bootstrap failed."
}

Write-Host "`n=== Preparing Grafana admin credentials ===" -ForegroundColor Cyan

# Create the namespace if it does not already exist.
$NamespaceYaml = kubectl create namespace observability --dry-run=client -o yaml

if ($LASTEXITCODE -ne 0) {
    throw "Failed to generate observability namespace manifest."
}

$NamespaceYaml | kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create or verify observability namespace."
}$ObservabilityNamespace = kubectl get namespace observability -o name 2>$null

if ($LASTEXITCODE -ne 0 -or -not $ObservabilityNamespace) {
    Invoke-Kubectl @("create", "namespace", "observability")
}

# Preserve existing credentials across bootstrap reruns.
$GrafanaSecretExists = kubectl get secret grafana-admin `
    -n observability --ignore-not-found -o name 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to check for the Grafana admin Secret."
}

if (-not $GrafanaSecretExists) {
    $RandomBytes = New-Object byte[] 32
$Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

try {
    $Rng.GetBytes($RandomBytes)
}
finally {
    $Rng.Dispose()
}

    $GrafanaPassword = [Convert]::ToBase64String($RandomBytes).
        TrimEnd('=').
        Replace('+', 'A').
        Replace('/', 'B')

    $GrafanaSecretFile = Join-Path $env:TEMP "grafana-admin-secret.yaml"

    $GrafanaSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: observability
type: Opaque
stringData:
  admin-user: admin
  admin-password: "$GrafanaPassword"
"@

    try {
        Set-Content -Path $GrafanaSecretFile -Value $GrafanaSecretYaml -Encoding utf8
        Invoke-Kubectl @("apply", "-f", $GrafanaSecretFile)
    }
    finally {
        Remove-Item $GrafanaSecretFile -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Created Grafana admin Secret. Password is not written to Git." -ForegroundColor Green
}
else {
    Write-Host "Grafana admin Secret already exists; preserving credentials." -ForegroundColor Yellow
}

Write-Host "`n=== Applying Argo CD root Application ===" -ForegroundColor Cyan

$RootApplication = Join-Path $RepoRoot "gitops\root-app.yaml"

if (-not (Test-Path $RootApplication)) {
    throw "Root Application manifest not found: $RootApplication"
}

Invoke-Kubectl @("apply", "-f", $RootApplication)

Write-Host "`n=== Waiting for root Application registration ===" -ForegroundColor Cyan

$RootAppReady = $false

for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
    $RootApp = kubectl get application root-app -n argocd -o name 2>$null

    if ($LASTEXITCODE -eq 0 -and $RootApp) {
        $RootAppReady = $true
        break
    }

    Start-Sleep -Seconds 2
}

if (-not $RootAppReady) {
    throw "Argo CD root Application was not registered within 120 seconds."
}

Invoke-Kubectl @("get", "application", "root-app", "-n", "argocd")

Write-Host "`nBootstrap completed: root Application submitted to Argo CD." -ForegroundColor Green
```
