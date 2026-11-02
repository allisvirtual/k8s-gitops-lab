# k8s-gitops-lab

A reproducible Kubernetes platform built from code (Terraform, ArgoCD,
Prometheus and Grafana) that deploys the same application through both a
push-based CI pipeline and a pull-based GitOps controller, and measures the
difference between them.

## Research question

How can a reproducible Kubernetes platform be set up with Terraform and managed
with ArgoCD, and to what extent does pull-based GitOps deployment improve
deployment lead time, configuration drift control and recoverability compared to
push-based CI deployment?

## The experiment

One cluster, one application, one monitoring stack, two delivery paths:

- **Push**: GitHub Actions runs `helm upgrade` against the cluster.
- **Pull**: ArgoCD watches `config/` in this repository and syncs the
  cluster to it.

Everything except the delivery path is shared on purpose, so the comparison
stays fair. Four metrics are measured on both paths, several runs each, reported
with their spread: deployment lead time, configuration drift control, recovery
time after a failed release, and time to rebuild the platform from nothing.

## Stack

| Component | Tool |
| --- | --- |
| Application | .NET minimal API |
| Local cluster | k3d |
| Cloud cluster | Azure Kubernetes Service |
| Infrastructure as code | Terraform |
| Packaging | Helm |
| GitOps controller | ArgoCD |
| CI and registry | GitHub Actions, GitHub Container Registry |
| Monitoring | Prometheus, Grafana |

## Layout

| Path | Contents |
| --- | --- |
| [`infra/`](infra/) | Terraform for the cluster and the ArgoCD install |
| [`demo-api/`](demo-api/) | .NET minimal API, Dockerfile, tests |
| [`config/`](config/) | Helm values and ArgoCD Application definitions |

In the GitOps setup `config/` is the single source of truth that ArgoCD follows,
so a change there is a deployment.

## Documentation

Everything written about the project lives in [`docs/`](docs/).

- [`docs/adr/`](docs/adr/): architecture decision records, one per tool choice,
  each stating context, options, decision and consequences.

## Getting started

Early days: the API, its container image and the local cluster exist. There is
no Helm chart, no CI pipeline and no ArgoCD yet, so nothing is deployed to
Kubernetes automatically. The rollback, rebuild and tear-down steps land in the
runbook as those parts are built.

### Prerequisites

| Tool | Check with | Needed for |
| --- | --- | --- |
| .NET SDK 9.0 | `dotnet --version` | building and testing the API |
| Docker Desktop, Linux containers | `docker version` | building the image, running k3d |
| k3d | `k3d version` | the local cluster |
| kubectl | `kubectl version --client` | talking to the cluster |

On Windows, k3d installs with `winget install k3d.k3d`.

### Run the API on its own

```
dotnet test demo-api/DemoApi.sln
dotnet run --project demo-api/DemoApi
```

Three endpoints, on the port `dotnet run` prints:

| Endpoint | Returns |
| --- | --- |
| `/health` | `Healthy`, or 503 when the `BreakHealth` flag is set |
| `/version` | the deployed build, as `{"version":"..."}` |
| `/metrics` | Prometheus text format |

`/version` is what the measurement scripts poll to detect that a release is
live. It reports `DEMO_API_VERSION` if that is set, otherwise the version baked
in at build time, otherwise `0.0.0-dev`.

`BreakHealth=true` makes `/health` fail on purpose. That is how the recovery
measurement gets a broken release to recover from.

Metrics come from `prometheus-net.AspNetCore`, chosen over the OpenTelemetry SDK
because two lines of setup give a working scrape endpoint, and this experiment
measures delivery rather than telemetry. Swapping it later touches one file.

### Build and run the container

```
docker build -t demo-api:0.1.0 --build-arg VERSION=0.1.0 demo-api
docker run --rm -p 8081:8080 demo-api:0.1.0
```

`VERSION` is what `/version` will report. The image runs as a non-root user.

### Create and delete the local cluster

```
./infra/local/cluster-up.ps1
./infra/local/cluster-down.ps1
```

`cluster-up.ps1` prints how long creation took, which is an input for the
rebuild metric. The cluster is described by
[`infra/local/k3d-cluster.yaml`](infra/local/k3d-cluster.yaml) so it can be
recreated identically before a measurement run.

To get the image into the cluster before a Helm chart exists:

```
k3d image import demo-api:0.1.0 -c gitops-lab
```

## Context

Solo experiment for the Complex Software Systems semester at Fontys HBO-ICT.

## License

[LICENSE](LICENSE)
