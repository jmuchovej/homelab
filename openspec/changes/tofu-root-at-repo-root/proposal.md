## Why

Every OpenTofu invocation today starts with `cd tofu`, because the root module lives in `tofu/` and OpenTofu offers no way to point at a different root except `-chdir`, which must precede the subcommand and cannot be injected through `TF_CLI_ARGS`. The rest of the repo just converged on root-relative paths (`flatten-src-tree`), the main checkout already carries an untracked root-level sketch of this move (`main.tofu`, `holonet.tofu`, an empty `terraform.tfstate`), and `tofu/AGENTS.md` and the root `AGENTS.md` both document `just tofu-plan` / `just tofu-apply` recipes that do not exist. Making the repository root the OpenTofu root module, with the smallest possible set of root-level `.tofu` files, resolves all three at once.

## What Changes

- **BREAKING (workflow)**: the OpenTofu root module becomes the repository root. `tofu init`, `tofu plan`, and `tofu apply` run from the repo root with no `cd` and no `-chdir`. Running them inside `tofu/` stops working (there is no root module there any more).
- The repo root holds exactly four source files, each with one job:
  - `main.tofu`: `required_providers`, an explicit `backend "local"` pointing at the existing state in `tofu/`, the shared sops data sources, every `provider` block (sops, cloudflare, onepassword, authentik, zerotier, the three `routeros` aliases, the two `kubernetes` aliases), `local.domain`, and the site-agnostic module instance (`module.authentik`).
  - `holonet.tofu`: unchanged content plus the ZeroTier network and members from `zerotier.tofu`. It already defines the WireGuard overlay and the holonet DNS records; the ZeroTier overlay is the same network, not a separate domain.
  - `da.tofu` and `en.tofu`: that site's relay module instances (from `da.mikrotik.tofu` / `en.mikrotik.tofu`), its apex and wildcard DNS records (from `da.cloudflare.tofu` / `en.cloudflare.tofu`), and its `module.kubernetes-<site>` discovery instance. `da.tofu` also absorbs the Cloudflare tunnel (currently the untracked `tofu/da.cloudflare-tunnel.tofu` in the main checkout) and the disabled-openbao comment block.
- `tofu/` keeps only child modules and their support files: `mikrotik/`, `authentik/`, `vault/`, the new `kubernetes/`, the two `*.just` modules, the `secrets` and `topology.yaml` symlinks (still consumed by the just recipes), local state and its backups, and `authentik.auto.tfvars.json`.
- New child module `tofu/kubernetes/`: one instance per site, bound to that site's `kubernetes` provider alias. It discovers `authentik.rbn/enabled=true` HTTPRoutes and, for remote sites, reads the `authentik-remote-cluster` ServiceAccount token and emits the kubeconfig. It replaces the hand-duplicated per-DC data sources in `ak.discovery.tofu` and `ak.service-connections.tofu`. The "only apps seen at more than one site get a `-<site>` suffix" rule moves into the authentik module, which owns the slugs it names.
- Retire one-shot blocks that have already landed in state: 106 `import` blocks (`da.mikrotik-imports.tofu`, `en.mikrotik-imports.tofu`, the authentik imports in `ak.tofu`, the ZeroTier network import) and the 5 `moved` blocks in `ak.moved.tofu`. `import` and `moved` blocks may only live in the root module, so carrying them costs five root files for zero effect. Every target is verified present in state before deletion.
- Remove `ak.variables.tofu`. Once the authentik imports are gone, the only consumer of `authentik-builtins` is the authentik module's `permissions` lookup, so the module reads `tofu/authentik.auto.tfvars.json` itself (guarded by `fileexists`) instead of the root declaring a variable that OpenTofu auto-loads from the root directory. `just authentik discover-all` keeps writing the same file to the same place.
- `.terraform.lock.hcl` moves to the repo root (tracked). `.terraform/` is regenerated at the root by `tofu init`; both locations are already gitignored.
- Root `justfile` gains the documented `tofu-plan` and `tofu-apply` recipes (`-parallelism=1 -compact-warnings`, pass-through args).
- `tofu/AGENTS.md`: `paths:` widened to cover root `*.tofu`; the Layout and Workflow sections rewritten (they currently cite `__main__.tofu`, `modules/mikrotik/`, and `cd`-based usage).
- Comments that name moved files are updated: `modules/services/zerotier.nix` (`tofu/zerotier.tofu`), `kubernetes/apps/network/cloudflare-tunnel/app/external-secret.yaml` (`tofu/da.cloudflare-tunnel.tofu`), `modules/inputs.nix` (the tool-tree list).

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `repo-layout`: the "OpenTofu lives under `tofu/`" requirement changes from "root module, child modules, state, and symlinks all under `tofu/`" to "root module at the repository root with a bounded set of root files; child modules, justfile modules, symlinks, and state under `tofu/`". The "Tool trees live at the repository root" requirement's OpenTofu clause is adjusted to match. The "Root justfile modules resolve" scenario is unchanged.

## Impact

- **Live infrastructure**: no resource changes state address. Module instance names (`module.da-relay01`, `module.authentik`, and so on) and every root-level resource keep their names; only the files they are declared in move, and module `source` paths gain a `tofu/` prefix. The new `tofu/kubernetes/` module holds data sources only. The acceptance gate is therefore strict: the first `tofu plan` at the repo root must report no changes, with zero `moved` blocks in play.
- **State**: stays at `tofu/terraform.tfstate` with its backups, selected by an explicit `backend "local" { path = ... }`. Nothing is migrated or copied. The stale `tofu/.terraform/` (provider cache and backend hash for the old root) is deleted after the new root initialises cleanly.
- **Main checkout (`/Users/john/Homelab`)**: its working copy carries uncommitted tofu work that this change collides with. Superseded by this change: the root-level `main.tofu` / `holonet.tofu` / empty `terraform.tfstate` sketch, `tofu/cloudflare/`, `tofu/kubernetes/`, `tofu/authentik/kube-service-connection/`, and the `just := ...` rewrite of `tofu/mikrotik.just`. Unrelated and untouched: `tofu/servarr/`, the `ak.discovery.tofu` and `tofu/authentik/*` edits, `tofu/.scratch/`. Untracked but live: `tofu/da.cloudflare-tunnel.tofu` declares four resources that exist in state (`cloudflare_zero_trust_tunnel_cloudflared.id`, its config, `cloudflare_dns_record.id-apex`, `onepassword_item.cf-tunnel-idp`); if it is not folded into `da.tofu` before the first root-level plan, that plan proposes destroying them. The tasks sequence this explicitly.
- **Just recipes**: `just authentik ...` and `just mikrotik ...` are unchanged; module recipes still run with `tofu/` as their working directory, which is why the two symlinks stay.
- **Editor tooling**: `tofu-ls` (wired in `modules/programs/development/languages/opentofu.nix`) now sees the repo root as the root module, which matches how the files are laid out. `treefmt`'s `terraform` formatter already matches `*.tofu` anywhere.
- **Not touched**: resource definitions inside `tofu/mikrotik/`, `tofu/authentik/`, `tofu/vault/`; state file contents; RouterOS, Cloudflare, Authentik, or ZeroTier objects; the `terraform` RouterOS user; `.sops.yaml` rules; the `secrets/` tree.
