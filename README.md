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
| [`config/`](config/) | Helm chart, values per environment, ArgoCD Application definitions |

In the GitOps setup `config/` is the single source of truth that ArgoCD follows,
so a change there is a deployment.

## Documentation

Everything written about the project lives in [`docs/`](docs/).

- [`docs/adr/`](docs/adr/): architecture decision records, one per tool choice,
  each stating context, options, decision and consequences.

## Getting started

The API, its container image, the local cluster, the Helm chart and ArgoCD
exist. The API can be deployed to k3d by hand with Helm (push) and by ArgoCD
from Git (pull). There is no CI pipeline yet. The rebuild and tear-down steps
land in the runbook as those parts are built.

### Prerequisites

| Tool | Check with | Needed for |
| --- | --- | --- |
| .NET SDK 9.0 | `dotnet --version` | building and testing the API |
| Docker Desktop, Linux containers | `docker version` | building the image, running k3d |
| k3d | `k3d version` | the local cluster |
| kubectl | `kubectl version --client` | talking to the cluster |
| Helm 4 | `helm version` | deploying the chart |

On Windows, k3d installs with `winget install k3d.k3d` and Helm with
`winget install Helm.Helm`.

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

### Deploy to the cluster

The chart is [`config/charts/demo-api/`](config/charts/demo-api/), and
[`config/values/k3d.yaml`](config/values/k3d.yaml) holds the values for the
local cluster. Both delivery paths will use exactly these files (see
[ADR-003](docs/adr/0003-packaging.md)).

Until CI pushes images to the registry, build the image and load it into the
cluster yourself:

```
docker build -t demo-api:0.1.0 --build-arg VERSION=0.1.0 demo-api
k3d image import demo-api:0.1.0 -c gitops-lab
helm upgrade --install demo-api config/charts/demo-api -f config/values/k3d.yaml --wait
curl http://localhost:8080/version
```

`--wait` returns once every pod is Ready, which is the moment the release
counts as done.

### Release a new version

Build and import a new tag, then upgrade with that tag:

```
docker build -t demo-api:0.2.0 --build-arg VERSION=0.2.0 demo-api
k3d image import demo-api:0.2.0 -c gitops-lab
helm upgrade demo-api config/charts/demo-api -f config/values/k3d.yaml --set image.tag=0.2.0 --wait
```

The rollout replaces one pod at a time and never removes a pod before its
replacement is Ready, so `/version` switches from `0.1.0` to `0.2.0` without
errors in between.

### Deploy a broken release and roll back

```
helm upgrade demo-api config/charts/demo-api -f config/values/k3d.yaml --set image.tag=0.2.0 --set breakHealth=true --wait --timeout 60s
```

The new pod fails its readiness probe on `/health`, so it never receives
traffic, the rollout stalls, and after 60 seconds Helm marks the release as
failed. The old pods keep serving the whole time. Recover with:

```
helm history demo-api
helm rollback demo-api --wait
```

`helm rollback` without a revision goes back to the previous release. This is
the push path's recovery action. On the GitOps path the same recovery will be a
`git revert`.

### Remove the release

```
helm uninstall demo-api
```

### Deploy with ArgoCD (GitOps)

```
./infra/local/argocd-up.ps1
```

This installs ArgoCD at a pinned version and registers
[`config/argocd/demo-api.yaml`](config/argocd/demo-api.yaml). From then on
ArgoCD keeps the `gitops` namespace identical to `config/` on `master` on
GitHub (see [ADR-005](docs/adr/0005-gitops-controller.md)). This release
answers on `http://gitops.localhost:8080`, next to the Helm release on
`http://localhost:8080`.

```
curl http://gitops.localhost:8080/version
```

Open the UI with the port-forward and password command the script prints, then
go to `http://localhost:8090` and log in as `admin`.

**Deploy by pushing.** Change `image.tag` in
[`config/values/k3d.yaml`](config/values/k3d.yaml), commit and push to
`master`. ArgoCD checks Git every 2 to 3 minutes; press Refresh in the UI to
check right away.

**Self-heal.** Change the cluster by hand and watch ArgoCD undo it:

```
kubectl scale deployment demo-api -n gitops --replicas=5
kubectl get pods -n gitops -w
```

The same command against the Helm release (`-n default`) stays at 5 replicas
until the next `helm upgrade`. That difference is what the drift measurement
compares.

**Recover.** On this side a bad release is undone with `git revert` and a push,
not with `helm rollback`.

## License

[LICENSE](LICENSE)
