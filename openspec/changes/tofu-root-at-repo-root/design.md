## Context

See proposal.md for motivation. The facts that shape the approach:

- OpenTofu loads exactly the `*.tofu` / `*.tf` files in one directory as the root module. There is no include mechanism, no environment variable for the root directory, and `-chdir` must precede the subcommand, so `TF_CLI_ARGS` cannot carry it (`tofu -help` lists it as a global option). "Bare `tofu` from the repo root" therefore means "the repo root is the root module".
- `provider` blocks, `module` instances, `import` blocks, `moved` blocks, and `backend` configuration are root-only constructs. Provider binding is static per module instance, so a `module` block cannot `for_each` over relays with different `routers` aliases. The three relay instances and the two per-site Kubernetes instances must each be spelled out in the root.
- The current root module in `tofu/` is 18 files. By job: provider setup (`main.tofu`, `sops.tofu`, `op.tofu`, `cloudflare.tofu`, provider blocks inside `ak.tofu`, `ak.discovery.tofu`, `da.mikrotik.tofu`, `en.mikrotik.tofu`), network definition (`holonet.tofu`, `zerotier.tofu`), per-site instances and records (`da.mikrotik.tofu`, `en.mikrotik.tofu`, `da.cloudflare.tofu`, `en.cloudflare.tofu`, `da.openbao.tofu`), authentik wiring (`ak.tofu`, `ak.discovery.tofu`, `ak.service-connections.tofu`, `ak.variables.tofu`), and one-shot blocks (`da.mikrotik-imports.tofu`, `en.mikrotik-imports.tofu`, `ak.moved.tofu`, the imports inside `ak.tofu` and `zerotier.tofu`).
- Live state (861 entries, local file `tofu/terraform.tfstate`, no `backend` block) holds four module roots (`module.authentik`, `module.da-relay01`, `module.da-relay02`, `module.en-relay01`) and 22 root-level resources: the per-site apex/wildcard records on Cloudflare and RouterOS, the three holonet A records, the ZeroTier network and six members, and four Cloudflare-tunnel resources whose only configuration is the untracked `tofu/da.cloudflare-tunnel.tofu` in the main checkout.
- Every `import` target checked (`zerotier_network.holonet`, `module.da-relay01.routers_system_user_group.terraform`, `module.en-relay01.routers_interface_bridge.bridge`, `module.authentik.authentik_flow.invalidation`) is in state, and the `moved` blocks have been applied (`authentik-app["actual-da"]` exists, `authentik-app["actual"]` does not). The authentik imports index `var.authentik-builtins.stages[...]`, so today a plan on a machine without `tofu/authentik.auto.tfvars.json` fails on an invalid index, not on the missing file.
- `tofu/authentik/main.tofu` already reads its sops inputs as `${path.root}/secrets/...`; `holonet.tofu` reads `${path.root}/topology.yaml`. With the root at the repo root these resolve to the real files. The `tofu/secrets` and `tofu/topology.yaml` symlinks are still read by `tofu/mikrotik.just` (`justfile_directory()/secrets/hosts/...`) and `tofu/authentik.just` (`secrets/secrets.sops.yaml` relative to the module's working directory, which `just` sets to `tofu/`).
- The main checkout's working copy carries the user's sketch of this move: a root `main.tofu` that inlines provider configuration plus `module.en-relay01`, `module.kubernetes-da`, `module.kubernetes-en`, and `module.en-service-connection`; a byte-identical root `holonet.tofu`; `tofu/kubernetes/main.tofu` (HTTPRoute discovery per site, with a `data.data.` typo); `tofu/cloudflare/{main,da}.tofu` (a module whose `da.tofu` references `module.da-relay01`, `routers.da-relay01`, and `local.catalog`, none of which a child module can see); and `tofu/authentik/kube-service-connection/main.tofu`, which creates an `authentik_service_connection_kubernetes` that `module.authentik` already creates in `apps.outposts.tofu`.
- `.gitignore` ignores `**/.terraform/*`, `*.tfstate`, `*.tfstate.*`, `*.tfvars`, and `*.tfvars.json` at any depth. `.terraform.lock.hcl` is tracked. `treefmt`'s `terraform` formatter matches `*.tofu` anywhere in the tree. `tofu-ls` treats the directory holding `.terraform/` as the root module.
- The repo's agent hooks reject writes whose content contains a literal parent-directory path segment, so this document names paths in words where a relative hop would otherwise appear.

## Goals / Non-Goals

**Goals:**

- `tofu <cmd>` at the repo root is the one way to run OpenTofu here. No `cd`, no `-chdir`, no wrapper.
- The root carries the fewest source files that OpenTofu's root-only constructs allow, each with a single job, and the count grows only with the number of sites.
- Zero state-address changes: the first plan at the new root is the acceptance test and must print "No changes".
- No new pass-through layers. A child module exists only where it owns resources or data for more than one call site.

**Non-Goals:**

- Moving relay data (port maps, wifi profiles, static leases, BGP peers) into `topology.yaml` so the `<site>.tofu` files shrink to a handful of lines per relay. That is the lever if the site files grow, and it is a schema change with its own review.
- Splitting state, adding a remote backend, or changing the `-parallelism=1` posture toward RouterOS.
- Touching resource definitions inside `tofu/mikrotik/`, `tofu/authentik/`, or `tofu/vault/` beyond the two authentik input changes described below.
- Landing `tofu/servarr/` or any other in-flight work in the main checkout.
- Renaming `authentik.auto.tfvars.json`.

## Decisions

### D1. The repo root is the root module. No wrapper, no symlinks.

Alternatives: (a) a devshell `tofu` function or `writeShellApplication` that prepends `-chdir=tofu`. It satisfies "bare `tofu` from the root" typographically, but the user excluded `-chdir` outright, and it makes the prompt lie: `path.root`, `.terraform/`, the lock file, and `*.auto.tfvars.json` all still resolve inside `tofu/`, and `tofu-ls` keeps a different root than the shell. (b) Root-level symlinks to `tofu/*.tofu`. OpenTofu follows them, but that is eighteen root entries and two directories that both look like root modules. Rejected: the point is fewer root files, not different ones.

### D2. Four root files split by job: `main.tofu`, `holonet.tofu`, `da.tofu`, `en.tofu`.

Module instances cannot leave the root, so the lower bound on root content is "where do the three relay instances and the two per-site discovery instances live". Three ways to arrange that:

- One `main.tofu` holding everything (the sketch's direction): about 500 lines mixing provider credentials, backend, and per-relay port maps and wifi profiles. Every change to a relay edits the file that holds every provider.
- Per-site wrapper modules (`tofu/da/`, `tofu/en/`) so the root is two files. Each wrapper needs `configuration_aliases` for every provider the site touches (two `routers`, `kubernetes`, `cloudflare`, `authentik`), re-declares `catalog` and `domain` only to forward them, produces two-deep addresses (`module.da.module.relay01...`) for all 436 RouterOS resources, and needs three module-level `moved` blocks to get there. That is exactly the pass-through layer the user called obtuse.
- One file per site. Sites are how the repo names everything (`<site>-<node>`), each file's provider aliases are its own, no state moves, and the count is bounded by the number of datacenters.

The third is chosen. `main.tofu` holds only what is site-agnostic and root-only: `required_providers`, `backend`, the shared sops data sources, every `provider` block, `local.domain`, and `module.authentik`. The provider blocks for `routers.<relay>` and `kubernetes.<site>` also live in `main.tofu` rather than in the site file, so "where are credentials configured" has one answer and a site file never carries a `provider` block.

### D3. ZeroTier folds into `holonet.tofu`.

`zerotier.tofu` is the ZeroTier half of the same overlay `holonet.tofu` already defines: the network's managed routes are `local.lab-routes` from `holonet.tofu`, the members are `local.topology.clients`, and the network id is written back into `local.catalog` for the relays. A `tofu/zerotier/` module would take three topology-derived inputs, return one id, and need two `moved` blocks. The provider block moves to `main.tofu`; the already-applied `import` is dropped.

### D4. Per-site DNS records stay root-level in the site file.

The sketch's `tofu/cloudflare/` module cannot work as written: its RouterOS CNAMEs need the `routers.<relay>` alias passed in, and its Cloudflare CNAMEs need each relay's `ddns_name` output plumbed through. Doing that costs eight `moved` blocks and gains a module with two instances of nothing shared. Pushing the RouterOS CNAMEs into `tofu/mikrotik/` via the catalog is plausible later (four `moved` blocks) but is a mikrotik-module change, not this one. The four records per site sit in `<site>.tofu` next to the relay whose DDNS name they track. The Cloudflare tunnel (da-only by its own comment) joins `da.tofu` for the same reason.

### D5. One `tofu/kubernetes/` child module, one instance per site, data only.

Today `ak.discovery.tofu` spells out namespace and HTTPRoute data sources twice, once per site, because a data source cannot pick its provider by key. A module instance can: `module.kubernetes-da` and `module.kubernetes-en` each receive one `kubernetes` provider and run the same two data sources. The module takes `site` and an optional `api-server` (the ZeroTier address of that site's API server, non-null only for remote sites), and outputs:

- `routes`: the site's discovered HTTPRoutes, already reduced to the per-app attribute object `ak.discovery.tofu` builds today (name, group, type, client_type, icon, access, skip_paths, basic_auth, url, redirect_uris), keyed by route name, with `site` set. It does not decide the `-<site>` suffix.
- `authentik-kubeconfig` (sensitive): the JSON kubeconfig assembled from the `authentik-remote-cluster` ServiceAccount secret, with the existing postcondition, or `null` when `api-server` is null. The secret read is `count = var.api-server == null ? 0 : 1`.

`module.authentik` gains a `routes-by-site` input (`map(map(object(...)))`, same object shape as today's `discovered-apps` entries minus `site-scoped`) and derives `local.discovered-apps` with the multi-site keying rule moved verbatim from `ak.discovery.tofu`; `apps.tofu` reads the local instead of the variable, and the `discovered-apps` variable is removed. The keying rule names authentik objects and sops keys, so it belongs with authentik. `remote-clusters` and `remote-cluster-kubeconfigs` keep their shape; the root builds them from the module outputs. Rejected: the sketch's `kube-service-connection` module, because `module.authentik` already creates that resource and moving it is a state move for no gain. Rejected: keeping discovery at root inside each site file, because that is the same 60 lines twice.

The state effect is nil: `kubernetes_resources` and `kubernetes_secret_v1` are data sources and are re-read at plan.

### D6. Applied `import` and `moved` blocks are deleted, after a per-address check against state.

The check is mechanical: extract every `to =` address from the five files, normalise the `for_each` imports in `da.mikrotik-imports.tofu` and `en.mikrotik-imports.tofu` by expanding their key sets from `local.da-ports` / `local.en-ports` (or by matching the address prefix), and require each to appear in `tofu state list`. Any miss keeps that block and stops the change. Alternative: keep them in one root `imports.tofu`. They are evaluated on every plan, cost the plan a hard dependency on `authentik.auto.tfvars.json`, and can never be for_each-collapsed across relays, so they are not a shape worth preserving.

### D7. The authentik module reads `tofu/authentik.auto.tfvars.json` itself.

With the imports gone, `permissions` is the only consumer of `authentik-builtins`. The module builds it as `fileexists(p) ? jsondecode(file(p))["authentik-builtins"]["permissions"] : {}` with `p = "${path.root}/tofu/authentik.auto.tfvars.json"`, so `permissions` becomes a local; the `permissions` variable, the root `authentik-builtins` variable, and `ak.variables.tofu` go away. `just authentik discover-all` and `discover-permissions` keep writing the same file to the same place (the module recipe's working directory is `tofu/`). Alternatives: keep the root variable and move the file to the root (one more ignored root file, and the recipe's `output` path changes); `TF_CLI_ARGS_plan="-var-file=..."` (environment magic that hard-fails when the file is absent). The file keeps its `.auto.tfvars.json` name because `*.tfvars.json` is already gitignored; OpenTofu no longer auto-loads it, and the `tofu/AGENTS.md` rewrite says so.

### D8. State stays put; the root selects it with an explicit local backend.

`backend "local" { path = "tofu/terraform.tfstate" }` in `main.tofu`. The path is relative to the root module directory, so the state file and its `.backup` sibling never leave `tofu/`, and the three manual `.bak` / dated snapshots stay next to it. `tofu init` at the root sees no prior `.terraform/`, so there is no backend-change prompt and no migration; it installs providers into a fresh `.terraform/` (already gitignored) and installs the child modules from `./tofu/<name>`. `.terraform.lock.hcl` moves from `tofu/` to the root as a plain rename; the provider hashes are unchanged. `tofu/.terraform/` is deleted only after the root plan is clean. Alternative: `TF_DATA_DIR=tofu/.terraform` to keep the provider cache in `tofu/`. It would also reuse the old backend hash and force a `-reconfigure`, and it moves `tofu-ls`'s root detection back into `tofu/`. Not worth an environment variable.

### D9. Root justfile gains `tofu-plan` and `tofu-apply`.

Both `AGENTS.md` files already describe them. Each is `tofu <plan|apply> -parallelism=1 -compact-warnings {{ ARGS }}` run at the repo root (no `working-directory` attribute needed). The `tofu/*.just` modules are untouched; the sketch's `just := "just --justfile " + source_file()` rewrite of `mikrotik.just` is unrelated to this change and is left to the main checkout.

### D10. `tofu/AGENTS.md` widens its glob and is rewritten in the same change.

`paths:` becomes `tofu/**` plus `*.tofu`. Its Layout section currently cites `__main__.tofu`, `modules/mikrotik/`, and directories that do not exist, and its Workflow section assumes `cd tofu`; both are rewritten to the four-root-file layout, the "provider blocks only in `main.tofu`" rule, the site-file rule, the retired-imports policy, the explicit backend path, and the discovery-file read. The landmine sections are kept verbatim. The `.agents/rules/tofu.md` link is unchanged.

### D11. The `tofu/secrets` and `tofu/topology.yaml` symlinks stay.

OpenTofu no longer needs them, but both just modules do (`mikrotik.just` through `justfile_directory()`, `authentik.just` through a relative `secrets/` and an explicit parent hop in `sync-outpost-tokens`). Repointing the recipes is a separate, small change; deleting the links now would break `just mikrotik ...` for nothing.

## Risks / Trade-offs

- [The first root plan proposes destroying the Cloudflare tunnel, `cloudflare_dns_record.id-apex`, and `onepassword_item.cf-tunnel-idp`] → Those four resources are configured only by the untracked `tofu/da.cloudflare-tunnel.tofu` in the main checkout. The cutover folds it into `da.tofu` before the first plan, and any destroy in that plan is a stop, not a prompt.
- [Main checkout working copy conflicts with the landed change] → The sketch files (`main.tofu`, `holonet.tofu`, `terraform.tfstate` at the root; `tofu/cloudflare/`, `tofu/kubernetes/`, `tofu/authentik/kube-service-connection/`) are superseded and must be removed there before the checkout advances; `tofu/servarr/`, the `ak.discovery.tofu` and `tofu/authentik/*` edits, and the `mikrotik.just` rewrite are unrelated and are the user's to keep, rebase, or drop. Tasks name each file and which side of the line it is on.
- [An `import` target is missing from state and its block is deleted anyway] → D6's per-address check runs before any deletion and refuses on the first miss. The `for_each` imports expand from the same `local.*-ports` maps the module instances use.
- [`fileexists` resolves against the wrong root] → `path.root` is the repo root by construction; task verifies with the file present and absent, and checks that `permissions` maps a known codename (`view_flow` style) in the present case.
- [The kubernetes provider must reach both clusters over ZeroTier at plan time] → Unchanged from today; the data sources were already root-level and evaluated at plan. The module boundary adds nothing.
- [`for_each` in `module.authentik` now keys off a module output] → The keys are HTTPRoute names read from data sources at plan time, exactly as today; OpenTofu's "cannot be determined until apply" error does not apply to data-source-known values.
- [Bare `tofu apply` at the root without `-parallelism=1`] → Same exposure as before the move; the just recipes and the rule text remain the guard.
- [Two directories look like tofu roots during the transition] → Only in the worktree between the move and the commit. Verification lists `tofu/*.tofu` and requires it empty.

## Migration Plan

1. In this worktree: create the four root files by moving blocks out of the fifteen, create `tofu/kubernetes/`, adjust `tofu/authentik/` inputs, delete the retired files, move the lock file, add the just recipes, rewrite the rule, update the three comments. `tofu validate` at the root needs providers, so `tofu init -backend=false` is the worktree check; the worktree has no state.
2. In the main checkout, after it advances to the commit: remove the superseded sketch files, fold `tofu/da.cloudflare-tunnel.tofu` into `da.tofu`, run `tofu init` at the root, then `just tofu-plan`. "No changes" is the gate. Then delete `tofu/.terraform/` and confirm `just tofu-plan` is still clean.
3. Rollback before step 2's plan is a `jj` restore; state has not been touched. There is no apply in this change at all.

## Open Questions

- Whether to rename `tofu/authentik.auto.tfvars.json` to something that does not imply auto-loading (needs a `.gitignore` line and a recipe `output` change). Deferrable; the rule text documents the current behaviour either way.
- Whether the RouterOS apex/wildcard CNAMEs should later move into `tofu/mikrotik/` through the catalog (four `moved` blocks). Deferrable; D4 keeps them root-level now.
