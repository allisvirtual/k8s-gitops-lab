# ADR-003: Packaging

- **Status**: Accepted
- **Date**: 2026-11-02
- **Jira**: KAN-23

## Context

The demo API is deployed to Kubernetes two ways: the push pipeline runs a
command against the cluster, and ArgoCD renders the same definition from Git.
For the comparison to be fair, both paths have to deploy exactly the same
manifests, so the packaging format is shared and must work unchanged for both.

The definition also has to be parameterised. A release changes the image tag,
the recovery measurement needs a switch that produces a broken release
(`breakHealth`), and the same application runs on k3d locally and on AKS in the
cloud, where for example the ingress controller differs. Those differences have
to be values, not copies of the manifests.

Finally, the push path needs a native way to roll back, because rollback time
on that path is one of the measured quantities.

## Decision

Helm. One chart in `config/charts/demo-api/`, with defaults in its
`values.yaml` and one values file per environment in `config/values/`
(currently `k3d.yaml`). The push path runs
`helm upgrade --install demo-api config/charts/demo-api -f config/values/k3d.yaml`,
and the ArgoCD Application will point at the same chart path and values file.

The chart lives in `config/` rather than in `demo-api/chart/`. In the GitOps
setup `config/` is what ArgoCD follows, and a template change is a deployment
just as much as a tag change is. Keeping the chart there means everything that
decides what runs in the cluster is in one folder, while `demo-api/` only
decides what is inside the image.

## Options considered

- **Helm** (chosen): templates plus values cover the tag, the broken release
  flag and the per environment differences without duplicating manifests. Helm
  keeps a release history in the cluster, so `helm rollback` is the push path's
  built in recovery action, and `helm upgrade --wait` gives a clear point at
  which a release counts as done. ArgoCD renders Helm charts natively, so the
  GitOps path uses the identical chart. The cost is Go templating, which is
  harder to read than plain YAML, and a release history that only the push path
  uses (ArgoCD renders the chart with `helm template` and does not create Helm
  releases).
- **Kustomize**: built into `kubectl`, and overlays patch plain YAML without
  templating, which is easy to review. It has no release concept, so the push
  path would have no native rollback and recovery would have to be a redeploy of
  an older commit. Changing the image tag and flipping a flag work well with
  overlays, but anything conditional, such as leaving the ingress out, needs a
  separate overlay instead of a value.
- **Plain manifests**: the simplest to read and to explain. There are no
  parameters, so the tag would be changed by editing or `sed`ing YAML, and k3d
  and AKS would need two copies of each file. No rollback either.
- **Helm with Kustomize on top**: rendering the chart and patching the result
  with Kustomize, which ArgoCD supports. It solves nothing this experiment has,
  and adds a second tool to every deployment.

## Consequences

- Push and GitOps deploy the same chart and the same values files, so the
  packaging is not a variable in the comparison.
- Rollback differs per path by design: `helm rollback` for push, `git revert`
  for GitOps. Each is the native recovery action of its path, which is what the
  recovery metric compares.
- The rollout uses `maxUnavailable: 0` with a readiness probe on `/health`. A
  broken release therefore never becomes Ready and the old pods keep serving.
  The recovery measurement has to treat "the rollout is stuck" as the failure
  signal, not "the API is down".
- `ingressClassName` is a value set per environment, so the templates contain no
  k3s specific field, as ADR-002 requires.
- Until CI pushes to GitHub Container Registry (KAN-24), the k3d values point at
  a locally built image that has to be loaded with `k3d image import`.
- The chart has to be versioned: `version` in `Chart.yaml` changes when a
  template changes, separately from the application version.
