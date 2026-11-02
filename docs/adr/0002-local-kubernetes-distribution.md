# ADR-002: Local Kubernetes distribution

- **Status**: Accepted
- **Date**: 2026-09-28
- **Jira**: KAN-20

## Context

Almost all work in this experiment happens on a local cluster. Azure runs on
student credit, so AKS is only used for validation runs, which makes the local
cluster the place where the push path, the GitOps path, the monitoring stack and
three of the four measurements actually live.

That puts two unusual demands on the choice. First, the cluster has to be
described by a file in this repository, because the rebuild metric times
recreating the platform from nothing and a cluster assembled by hand cannot be
measured that way. Second, creating and deleting it has to be fast, because a
clean cluster is the starting condition for every repetition of every
measurement, and the runs are repeated several times.

Beyond that the cluster is ordinary: it has to run ArgoCD, Prometheus, Grafana
and one small .NET service, and it has to serve HTTP so that a measurement
script can poll `/version` from the host.

## Decision

k3d, with the cluster described in `infra/local/k3d-cluster.yaml` and created and
deleted by the two scripts next to it.

## Options considered

- **k3d** (chosen): runs k3s inside Docker containers. The whole cluster is one
  config file, creating and deleting it takes tens of seconds, and it ships with
  Traefik as ingress controller and a load balancer, so there is nothing extra to
  install before the API is reachable from the host. Docker Desktop is already
  running on the machine for building the image, so it adds no new runtime. Extra
  nodes are one line in the config, which is useful when a drift experiment
  scales replicas. The cost is that k3s is not upstream Kubernetes.
- **kind**: also fully config-file driven and deliberately close to upstream
  Kubernetes, which would transfer to AKS slightly better than k3s does. It
  brings no ingress controller, so an ingress install plus `extraPortMappings`
  would have to be added and maintained before anything is reachable. That is
  setup work that does not answer a research question.
- **minikube**: the most add-ons and the widest driver support, but heavier,
  slower to start, and single node by default. Its add-on model configures the
  cluster through CLI commands rather than through one file, which works against
  reproducing it from the repository.
- **Docker Desktop Kubernetes**: the least effort to get a cluster, and it is
  already installed. It is configured through a settings checkbox instead of a
  file, cannot be described in this repository, and resetting it is a GUI action.
  That rules it out, because the rebuild measurement has to be scripted.
- **k3s on a Fontys Netlab VM**: closest to a real server, always on, and it
  would remove Docker Desktop from the measurement path. It is a machine to
  install and keep reachable, it has to stay available for the whole project, and
  timing a rebuild would mean reinstalling a VM. That is more operational work
  than this experiment needs, and it is outside the research question.

## Consequences

- k3s is not upstream Kubernetes: it uses Traefik rather than an nginx ingress,
  and its own default storage class. The Helm chart has to run unchanged on both
  k3d and AKS, so no k3s specific field may leak into the manifests. Any
  remaining difference between local and AKS results is reported as a threat to
  validity, since the local and cloud clusters are not the same distribution.
- The cluster is disposable, and `cluster-up.ps1` prints its own creation time.
  That number feeds the rebuild metric directly and needs no separate script.
- The k3s image version is not pinned yet. It must be pinned in the config
  before the first real measurement run, otherwise a k3d upgrade changes the
  Kubernetes version between runs and the runs stop being comparable.
- The cluster runs on Docker Desktop on the development machine, so measurements
  share hardware with editors, browsers and builds. Runs are done with no other
  heavy work in progress, and this is named as a source of noise in the results.
- Ingress is published on `http://localhost:8080`. Until a Helm chart and an
  ingress exist, reaching the API means `kubectl port-forward`.
- The scripts are PowerShell, matching the Windows development machine. CI runs
  on Linux, so anything CI needs to do to a cluster cannot rely on them.
