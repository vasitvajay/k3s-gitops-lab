
# Bootstrap the local k3s cluster and install Argo CD.
# Prerequisites: Docker Desktop, k3d, kubectl.
# Safe to rerun: an existing cluster is reused.

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

Write-Host "`n=== Building NOVA Store image ===" -ForegroundColor Cyan

$RepoRoot = Split-Path $PSScriptRoot -Parent
$DockerfileContext = Join-Path $RepoRoot "apps\sample-api"

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

Write-Host "`nBootstrap completed successfully." -ForegroundColor Green
