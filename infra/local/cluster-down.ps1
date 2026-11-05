#Requires -Version 7
<#
.SYNOPSIS
    Deletes the local k3d cluster.
#>

$ErrorActionPreference = 'Stop'

$clusterName = 'gitops-lab'

if (-not (Get-Command 'k3d' -ErrorAction SilentlyContinue)) {
    throw "'k3d' is not on PATH. See the prerequisites in the repository README."
}

k3d cluster delete $clusterName
if ($LASTEXITCODE -ne 0) {
    throw "k3d cluster delete failed with exit code $LASTEXITCODE."
}

Write-Host ''
Write-Host "Cluster '$clusterName' deleted."
