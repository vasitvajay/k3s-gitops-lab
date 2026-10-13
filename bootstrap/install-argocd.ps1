
# Install Argo CD using a pinned release.
# Run from Windows PowerShell with kubectl configured.

$ErrorActionPreference = "Stop"

$Namespace = "argocd"
$ArgoCDVersion = "v3.5.5"
$ManifestUrl = "https://raw.githubusercontent.com/argoproj/argo-cd/$ArgoCDVersion/manifests/install.yaml"

Write-Host "Checking Kubernetes connectivity..."

kubectl cluster-info
if ($LASTEXITCODE -ne 0) {
    throw "Cannot reach Kubernetes. Ensure the k3d cluster is running."
}

Write-Host "Ensuring namespace '$Namespace' exists..."

kubectl get namespace $Namespace *> $null
if ($LASTEXITCODE -ne 0) {
    kubectl create namespace $Namespace
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create namespace '$Namespace'."
    }
}

Write-Host "Installing Argo CD $ArgoCDVersion..."

kubectl apply `
    --server-side `
    --force-conflicts `
    -n $Namespace `
    -f $ManifestUrl

if ($LASTEXITCODE -ne 0) {
    throw "Argo CD installation failed."
}

Write-Host "Waiting for Argo CD components..."

kubectl rollout status statefulset/argocd-application-controller `
    -n $Namespace --timeout=300s

if ($LASTEXITCODE -ne 0) {
    throw "Argo CD application controller did not become ready."
}

kubectl rollout status deployment/argocd-server `
    -n $Namespace --timeout=300s

if ($LASTEXITCODE -ne 0) {
    throw "Argo CD server did not become ready."
}

kubectl get pods -n $Namespace

Write-Host "Argo CD bootstrap completed successfully."
