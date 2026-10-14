---
paths:
  - "kubernetes/components/github-runner/**"
---

# github-runner/ — one ARC scale set per GitHub repository

A shared-path Kustomization holding the `HelmRelease` that makes up an [ARC](https://github.com/actions/actions-runner-controller) runner scale set, plus the hook-template `ConfigMap` that sizes the pods it spawns.
Adding a repo to the fleet is one `*.ks.yaml` under `apps/actions-runner-system/runners/` — no directory copy.

## Parameters

| Variable      | Example     | Default | Purpose                                                                            |
| ------------- | ----------- | ------- | ---------------------------------------------------------------------------------- |
| `GH_OWNER`    | `jmuchovej` | —       | Account or org that owns the repo                                                  |
| `GH_REPO`     | `homelab`   | —       | Repo name (the registration URL)                                                   |
| `RUNNER_NAME` | `homelab`   | —       | Scale set name: what workflows put in `runs-on:`, and the prefix of every k8s name |
| `RUNNER_MAX`  | `2`         | —       | Ceiling on concurrent runners for this scale set                                   |
| `JOB_CPU`     | `4`         | `2`     | CPU request of a `container:` job pod; nothing is CPU-limited                      |
| `JOB_MEMORY`  | `16Gi`      | `8Gi`   | Memory request and limit of a job pod; memory limit of the runner container        |
| `JOB_SCRATCH` | `40Gi`      | `20Gi`  | `ephemeral-storage` limit: whatever a job writes outside the workspace             |
| `RUNNER_DISK` | `100Gi`     | `30Gi`  | Work-volume PVC size — the workspace the runner pod and job pod share              |

`minRunners` is fixed at 0 — every scale set idles free.

`RUNNER_NAME` must be unique in the namespace: the chart derives every resource name from `runnerScaleSetName`, not from the Helm release name, so two scale sets sharing it collide on their ServiceAccount, Role, and RoleBinding.
It is the repo name for a repo's default scale set and `<repo>-<size>` for sized ones, so workflows use `runs-on: <repo>` or `runs-on: <repo>-<size>`.

## Sizes

ARC matches a job to a scale set by exact name — no labels, no parsing — so every `runs-on:` value is a declared scale set with its own listener pod.
A "size" is therefore just another `*.ks.yaml` for the same repo (`waypoints-xl.ks.yaml` → `RUNNER_NAME: waypoints-xl`) with different numbers; a single-runner repo omits the size variables and takes the defaults.
Size names are mutable aliases: changing what `xl` means is a one-file edit, whereas a spec-encoded name like `waypoints-8cpu-32gb` is a new GitHub registration plus a workflow edit in every consumer.

A job runs in one of two places, so a size sets both:

- a job **without** `container:` runs inside the runner container, so `JOB_MEMORY` and `JOB_SCRATCH` are its limits;
- a job **with** `container:` runs in a pod the runner-container-hooks create, and `hook-template.yaml` is merged into that pod via `ACTIONS_RUNNER_CONTAINER_HOOK_TEMPLATE`, carrying the same numbers as requests and limits.

The runner container's _requests_ deliberately stay at `100m` / `512Mi`: it is only an orchestrator while a job pod runs, and sizing it too would reserve every job twice.
No CPU limit anywhere — throttling a compiler only makes jobs slower; `JOB_CPU` is a request, which buys scheduling and CPU shares under contention.

`RUNNER_DISK` is the ephemeral work PVC mounted at `/home/runner/_work` in both pods.
The `zfs` classes provision datasets without `thinprovision`, which is thin by default: the size is a ZFS quota, not a reservation, so set it for the largest job in the repo — small jobs cost nothing.
Only the workspace lands there.
Anything a job writes elsewhere in its container (`~/.cargo`, `/nix/store`, SDK downloads) goes to the node's image filesystem, is capped by `JOB_SCRATCH`, and is evicted by kubelet at 5% free; point big caches into the workspace instead.

## Why per-repo and not one shared scale set

GitHub registers self-hosted runners at **repository, organization, or enterprise** scope only; there is no user-account scope (the REST API exposes `/repos/{owner}/{repo}/actions/runners` and `/orgs/{org}/actions/runners`, and nothing under `/users/`).
While the repos live under a personal account, one scale set per repo is the only option.

This costs little: the controller, both chart `OCIRepository`s, and the GitHub App credential are all shared and live once in `apps/actions-runner-system/actions-runner-controller/app`.
A scale set adds one small listener pod.

If these repos ever move into an org, this collapses to a single scale set pointed at `https://github.com/<org>`: delete the per-repo `*.ks.yaml` files, add one, and update `runs-on:` once per repo.

## Credentials

Authentication is a GitHub App, not a PAT — installation tokens are minted per-request and scoped to the installation.
A GitHub App installed on a personal account has **one** installation ID with a per-repo access list, so the same secret serves every scale set: granting the App access to a new repo plus one `*.ks.yaml` is the whole onboarding.
