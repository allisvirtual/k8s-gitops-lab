# ADR-005: GitOps controller

- **Status**: Accepted
- **Date**: 2026-11-05
- **Jira**: KAN-29

## Context

The pull-based setup needs a controller inside the cluster that watches
`config/` in this repository and makes the cluster match it. It has to deploy
the same Helm chart and values file that the push path deploys (ADR-003), so
that the delivery path is the only difference between the two setups.

Two of the measured quantities depend directly on how the controller behaves:
drift control (does a manual `kubectl` change get reverted, and how fast) and
lead time (how long after a push does the controller notice the commit). The
controller has to be installable from code, on k3d now and through Terraform on
AKS later, so the rebuild metric can time it.

## Decision

ArgoCD, installed with its official Helm chart at a pinned version
(`infra/local/argocd-up.ps1`, `infra/local/argocd-values.yaml`). One ArgoCD
Application (`config/argocd/demo-api.yaml`) follows `config/charts/demo-api` on
`master` with automated sync, self-heal and prune.

## Options considered

- **ArgoCD** (chosen): renders Helm charts natively, so the push path's chart
  and values file are used as they are. Self-heal and prune are two switches on
  the Application. It has a web UI that shows the live state, the Git state and
  every difference between them, which makes drift visible during a demo and
  easy to verify during a measurement. It is the most widely used GitOps
  controller, so the result is relevant to small teams choosing one. The cost
  is a heavier install (several components, its own Redis) and a UI with its
  own login to manage.
- **Flux**: lighter, built from small controllers, and closer to plain
  Kubernetes objects. It also deploys Helm charts, but through its own
  HelmRelease objects, which adds a second definition next to the values file.
  It has no built in UI, so drift and sync state are read from the command line.
  Functionally it would answer the research question equally well; ArgoCD wins
  on visibility and on matching the project plan, which names ArgoCD in the
  research question itself.
- **No controller, a CI job that reapplies on a schedule**: a push pipeline
  that runs every few minutes. It would revert drift eventually, but it is
  still push-based, so it cannot be the pull-based side of the comparison.

## Consequences

- Git polling stays at the chart default: every 120 seconds plus up to 60
  seconds of jitter. That delay dominates GitOps lead time and is reported as a
  known bias, not tuned away. A webhook (KAN-54) would remove it and is parked.
- Self-heal does not wait for polling: ArgoCD watches the live cluster, so a
  manual change is reverted within seconds. Drift results are therefore not
  affected by the polling interval.
- The push release and the GitOps release run side by side on k3d, in the
  `default` and `gitops` namespaces. Only the ingress host differs
  (`localhost` and `gitops.localhost`), so both use the same chart and the same
  values file.
- ArgoCD reads the public GitHub repository. Changes are only deployed once they
  are pushed to `master`; uncommitted or unpushed work is invisible to it.
- ArgoCD renders the chart itself and does not create Helm releases, so
  `helm history` and `helm rollback` do not apply to the GitOps side. Recovery
  there is a `git revert`, which is what the recovery metric compares.
- The initial admin password is generated in the cluster and never stored in
  Git. The UI is only reachable through a local port-forward.
