#Requires -Version 7
<#
.SYNOPSIS
    Creates the local k3d cluster and prints how long it took (input for the rebuild metric).
#>

$ErrorActionPreference = 'Stop'

$clusterName = 'gitops-lab'
$configPath = Join-Path $PSScriptRoot 'k3d-cluster.yaml'

foreach ($tool in 'k3d', 'kubectl') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "'$tool' is not on PATH. See the prerequisites in the repository README."
    }
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

k3d cluster create --config $configPath
if ($LASTEXITCODE -ne 0) {
    throw "k3d cluster create failed with exit code $LASTEXITCODE."
}

kubectl wait --for=condition=Ready nodes --all --timeout=120s
if ($LASTEXITCODE -ne 0) {
    throw "The nodes did not become Ready in time."
}

$stopwatch.Stop()

Write-Host ''
Write-Host ("Cluster '{0}' ready in {1:N1} seconds." -f $clusterName, $stopwatch.Elapsed.TotalSeconds)
Write-Host ''
kubectl get nodes
