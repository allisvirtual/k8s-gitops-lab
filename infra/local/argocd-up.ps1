#Requires -Version 7
<#
.SYNOPSIS
    Installs ArgoCD on the local k3d cluster and registers the demo API.

.DESCRIPTION
    Installs the ArgoCD Helm chart with argocd-values.yaml, then applies the
    Application in config/argocd/. From that point ArgoCD deploys whatever is
    on master in config/, so nothing else has to be run to deploy.

    Run cluster-up.ps1 first.

.EXAMPLE
    ./argocd-up.ps1
#>

$ErrorActionPreference = 'Stop'

# Pinned so that every rebuild installs the same ArgoCD (app version v3.6.1).
$chartVersion = '10.12.1'
$valuesPath = Join-Path $PSScriptRoot 'argocd-values.yaml'
$applicationPath = Join-Path $PSScriptRoot '..' '..' 'config' 'argocd' 'demo-api.yaml'

foreach ($tool in 'helm', 'kubectl') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "'$tool' is not on PATH. See the prerequisites in the repository README."
    }
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

helm repo add argo https://argoproj.github.io/argo-helm --force-update
if ($LASTEXITCODE -ne 0) {
    throw "Adding the argo Helm repository failed with exit code $LASTEXITCODE."
}

helm upgrade --install argocd argo/argo-cd `
    --version $chartVersion `
    --namespace argocd --create-namespace `
    --values $valuesPath `
    --wait --timeout 5m
if ($LASTEXITCODE -ne 0) {
    throw "Installing ArgoCD failed with exit code $LASTEXITCODE."
}

kubectl apply -f $applicationPath
if ($LASTEXITCODE -ne 0) {
    throw "Applying the demo-api Application failed with exit code $LASTEXITCODE."
}

$stopwatch.Stop()

Write-Host ''
Write-Host ("ArgoCD ready in {0:N1} seconds." -f $stopwatch.Elapsed.TotalSeconds)
Write-Host ''
Write-Host 'Open the UI:'
Write-Host '  kubectl port-forward svc/argocd-server -n argocd 8090:80'
Write-Host '  http://localhost:8090, user admin, password from:'
Write-Host '  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | %{ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }'
