# github-runner/ — one ARC scale set per GitHub repository

A shared-path Kustomization holding the single `HelmRelease` that makes up an
[ARC](https://github.com/actions/actions-runner-controller) runner scale set.
Adding a repo to the fleet is one `*.ks.yaml` under
`apps/actions-runner-system/runners/` — no directory copy.

## Parameters

| Variable     | Example     | Purpose                                       |
| ------------ | ----------- | --------------------------------------------- |
| `GH_OWNER`   | `jmuchovej` | Account or org that owns the repo             |
| `GH_REPO`    | `homelab`   | Repo name; also `runs-on:` and every k8s name |
| `RUNNER_MAX` | `2`         | Ceiling on concurrent runners for this repo   |

`minRunners` is fixed at 0 — every scale set idles free.

`GH_REPO` cannot be hoisted into a constant: the chart derives every resource
name from `runnerScaleSetName`, not from the Helm release name, so two scale
sets sharing that value collide on their ServiceAccount, Role, and RoleBinding
in this namespace. Workflows therefore use `runs-on: <repo>`.

## Why per-repo and not one shared scale set

GitHub registers self-hosted runners at **repository, organization, or
enterprise** scope only; there is no user-account scope (the REST API exposes
`/repos/{owner}/{repo}/actions/runners` and `/orgs/{org}/actions/runners`, and
nothing under `/users/`). While the repos live under a personal account, one
scale set per repo is the only option.

This costs little: the controller, both chart `OCIRepository`s, and the GitHub
App credential are all shared and live once in
`apps/actions-runner-system/actions-runner-controller/app`. A scale set adds
one small listener pod.

If these repos ever move into an org, this collapses to a single scale set
pointed at `https://github.com/<org>`: delete the per-repo `*.ks.yaml` files,
add one, and update `runs-on:` once per repo.

## Credentials

Authentication is a GitHub App, not a PAT — installation tokens are minted
per-request and scoped to the installation. A GitHub App installed on a
personal account has **one** installation ID with a per-repo access list, so
the same secret serves every scale set: granting the App access to a new repo
plus one `*.ks.yaml` is the whole onboarding.
