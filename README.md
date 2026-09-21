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

Not yet available. Prerequisites and the setup, deploy, rollback, rebuild and
tear-down steps land in the runbook as the platform is built.

## Context

Solo experiment for the Complex Software Systems semester at Fontys HBO-ICT.

## License

[LICENSE](LICENSE)
