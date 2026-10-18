# Proposal

## Why

The shared network topology exists twice: `topology.yaml`, which every consumer reads, and `topology.toml`, which is the only copy validated by `topology.schema.json` (via tombi) and by the `checks.topology` flake check.
The two have already drifted — `da-n1x`'s WireGuard `public` key and `da-relay02`'s `uplink` each exist in only one of them — so the validated file is not the file that configures anything.

## What Changes

- Every consumer reads `topology.toml` instead of `topology.yaml`:
  - the Nix modules (`kubernetes`, `zerotier`, `nfs`, `time`, `wg-holonet`) switch from `lib.rbn.from-yaml` (import-from-derivation through `yq`) to the pure builtin `lib.importTOML`;
  - the OpenTofu root module reads the file through the `tobotimus/toml` provider's `toml_file` data source, because OpenTofu has no built-in TOML decoder;
  - `bootstrap/mikrotik/justfile` reads roles and trunks with `yq -p toml`;
  - `kubernetes/justfile` keeps nushell's `open`, which already parses TOML.
- `tofu/topology.yaml` (symlink) is replaced by `tofu/topology.toml` (symlink to the repo-root file).
- `topology.toml` gains `da-n1x`'s `public` key so the data is identical to what `topology.yaml` holds today.
- **BREAKING** (repo-internal): `topology.yaml` is deleted.
  Anything outside this repository that reads it — none is known — would break.
- Rules, `AGENTS.md` files, and comments that name `topology.yaml` are updated to name `topology.toml`.
- The in-flight changes `talos-guest-clusters`, `tofu-per-site-modules`, and `docs-site-multi-domain` are updated to read, extend, and describe `topology.toml`, and `docs-site-multi-domain`'s `repo-layout` delta becomes a superset of this change's, since it archives after this one.
- `lib.rbn.from-yaml` loses its topology caller but stays: `talos-guest-clusters` reads its HelmChart CRs through it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `repo-layout`: the shared network topology lives at `topology.toml`; the `tofu/` symlink and the plan-is-a-no-op scenario name `topology.toml`; "Tool trees live at the repository root" gains a "No YAML copy of the topology remains" scenario.
- `bootstrap`: bootstrap subdirectories reach `topology.toml` as a repo-root file, and MikroTik role and trunk ports come from it.

## Impact

- **Code:** `modules/services/{kubernetes/kubernetes,zerotier,nfs}.nix`, `modules/system/{time,networking/wg-holonet}.nix`, `tofu/holonet.tofu`, `tofu/main.tofu` (`required_providers`), `tofu/.terraform.lock.hcl`, `bootstrap/mikrotik/justfile`, `kubernetes/justfile`.
- **Dependencies:** adds the OpenTofu provider `tobotimus/toml` pinned to `0.3.0`; drops the `yq` IFD from every Nix consumer of the topology.
- **Data:** `topology.toml` gains one key; `topology.yaml` and `tofu/topology.yaml` are removed.
- **Docs:** `tofu/AGENTS.md`, `bootstrap/AGENTS.md`, `kubernetes/AGENTS.md`, and comments in `modules/services/zerotier.nix`, `modules/system/networking/wg-holonet.nix`, `bootstrap/mikrotik/justfile`, and the four `kubernetes/clusters/*/flux` files that say "must track topology.yaml".
- **In-flight changes:** `openspec/changes/talos-guest-clusters/{proposal,design,tasks}.md`, `openspec/changes/tofu-per-site-modules/{design.md,specs/tofu-root-module/spec.md}`, and `openspec/changes/docs-site-multi-domain/specs/repo-layout/spec.md`.
- **Systems:** no deployed behavior changes; every host build and `tofu plan` is expected to be a no-op.
