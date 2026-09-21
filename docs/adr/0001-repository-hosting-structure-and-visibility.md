# ADR-001: Repository hosting, structure and visibility

- **Status**: Accepted
- **Date**: 2026-09-21
- **Jira**: KAN-19

## Context

Every part of this experiment lives in git: the Terraform code, the demo API and
the deployment config that ArgoCD follows. So the first thing to decide is where
that repository is hosted, how it is split and who can see it. These three
choices are made at the same moment, when the repository is created, so they
are recorded together.

A few things limit the options. This is a solo project, so there is no team that
needs separate access rights. ArgoCD has to be able to read the repository from
both the local k3d cluster and AKS.

## Decision

- **Hosting**: GitHub, personal account.
- **Structure**: one repository with `infra/`, `demo-api/`, `config/`.
- **Visibility**: public.

## Options considered

### Hosting

- **GitHub** (chosen): code, CI (GitHub Actions) and the container registry
  (GHCR) sit on one platform, so there are fewer accounts and integrations to
  set up. It stays available and is easy to share. Less familiar than GitLab
  which introduces opportunity to learn.
- **Fontys GitLab**: the course standard and already familiar. It is tied to my
  student account, and Fontys Gitlab does not provide shared runners.
- **GitLab.com**: stays available but already familiar so doesn't introduce new
  knowledge.
- **Azure DevOps Repos**: fits with AKS, but Azure DevOps no longer allows new
  public projects. Additionally, it introduces more fees.
- **Self-hosted Forgejo or Gitea**: the most to learn, but it is an extra system
  to run and keep reachable from AKS, which is outside the scope of this
  research.

### Structure

- **Three repositories** (infra, app, config): this is what the ArgoCD best
  practices recommend, because it keeps application history apart from config
  history and allows separate access control. Good for big projects and large teams.
- **Two repositories** (app, and infra plus config): a middle ground with most
  of the same benefits.
- **One repository** (chosen): going against the ArgoCD advice here is a
  conscious choice. The benefits of splitting are mostly about teams and access
  control, which a solo project does not need. One repository keeps the whole
  experiment in one history and makes it easier for a reviewer to follow.

### Visibility

- **Public** (chosen): ArgoCD can read the repository without credentials, GitHub
  Actions minutes are free for public repositories, and the work is directly
  visible as portfolio evidence.
- **Private**: ArgoCD would need repository credentials (a deploy key or token),
  which is one more secret to manage and a small extra step in every setup.

## Consequences

- If CI commits image tag updates into `config/`, this could start the
  pipeline again. This is prevented in two ways: commits pushed with
  `GITHUB_TOKEN` do not trigger new workflow runs, and `on.push.paths` filters
  limit which changes start a workflow.
- Because the repository is public, no secret may ever be committed. Secret
  scanning and push protection are enabled.
- ArgoCD needs no repository credentials, which keeps the setup simpler.
- The default branch is `master`. A ruleset protects it against deletion and
  force pushes.
- A read-only mirror to Fontys GitLab is optional.
- This decision should be revisited if keeping app and config in one repository
  makes the pipeline hard to control, or if config ever needs its own access
  rules. In that case `config/` would move to a separate repository.
