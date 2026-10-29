# Design

## Context

See `proposal.md` (Why) for motivation.
Today four kinds of consumer read `topology.yaml`, each with its own parser:

- Nix: `lib.rbn.from-yaml` (in `modules/_lib/yaml.nix`), which runs `yq` inside a derivation and reads the result back — import-from-derivation, and the reason `wg-holonet.nix` threads `pkgs` and an extended `lib` into a `read-topology` helper.
  `topology.yaml` is the helper's only current caller.
- OpenTofu: `yamldecode(file("${path.root}/topology.yaml"))` in `tofu/holonet.tofu`, with `tofu/topology.yaml` a symlink to the root file.
  OpenTofu 1.13 has no `tomldecode`; the registry's only TOML provider is `tobotimus/toml` (one maintainer, `toml_file` data source, no provider functions).
- `bootstrap/mikrotik/justfile`: `yq` (Go yq, which reads TOML with `-p toml`) for `role` and `trunks`.
- `kubernetes/justfile`: nushell `open`, which already dispatches on extension.

`topology.toml` is already validated by `topology.schema.json` and `checks.topology`; it differs from `topology.yaml` only by `da-n1x.public` (missing) and `da-relay02.uplink` (added).

Three in-flight changes name `topology.yaml` and none has a completed task: `talos-guest-clusters` (reads and extends the topology), `tofu-per-site-modules` (restructures the OpenTofu root that reads it), and `docs-site-multi-domain` (MODIFIES the same `repo-layout` requirement this change does).

## Goals / Non-Goals

**Goals:**

- One topology file; every consumer reads it; every host's topology-derived configuration and `tofu plan` are unchanged.
- No new parsing step in Nix — no import-from-derivation for the topology.
- Every in-flight change that names `topology.yaml` is updated to `topology.toml` in the same change, so none is applied against a file that no longer exists.

**Non-Goals:**

- Restructuring the topology's data model, or adding validation beyond what `topology.schema.json` and `checks.topology` already do — except the schema extension `talos-guest-clusters` needs, which lands in that change, not this one.
- Removing `lib.rbn.from-yaml` or `render-yaml`; see "`lib.rbn.from-yaml` stays" below.
- Applying any in-flight change, or editing archived changes.

## Decisions

### Nix reads the file with `lib.importTOML`

`lib.importTOML` is `builtins.fromTOML (builtins.readFile path)`: pure, no `pkgs`, no derivation.
Each consumer replaces `lib.rbn.from-yaml <path> { inherit pkgs; }` with `lib.importTOML <path>`, and `wg-holonet.nix`'s `read-topology lib pkgs` helper collapses to a single let-bound value, since the flake-parts `lib` already carries `importTOML` and needs no `lib.rbn` extension.

- _Alternative:_ a `lib.rbn.from-toml` wrapper for symmetry with `from-yaml`.
  Rejected — it would wrap a one-call builtin.

### `lib.rbn.from-yaml` stays

After this change nothing in the tree calls `from-yaml`, but `talos-guest-clusters` (its D6) reads the Cilium and Flux-operator HelmChart CRs under `bootstrap/kubernetes/` through it — YAML that is not the topology and has no TOML form.
Deleting it here would only force that change to re-add it.
The helper is therefore a known dependency of an in-flight change, not dead code; if `talos-guest-clusters` is abandoned, `from-yaml` becomes dead code and is removed then.

- _Alternative:_ delete it now and give `talos-guest-clusters` a task to reintroduce it.
  Rejected — churn with no intermediate benefit.

### OpenTofu reads the file through `tobotimus/toml`

`tofu/holonet.tofu` declares `data "toml_file" "topology" { input = file("${path.root}/topology.toml") }` and `local.topology = data.toml_file.topology.content`.
The provider is pinned to exactly `0.3.0` in `required_providers`, and `.terraform.lock.hcl` pins its hashes, so the supply-chain exposure is limited to deliberate upgrades.
The data source's input is a literal file read, so it is known at plan time and `local.topology` stays usable in `for_each` keys.

- _Alternative:_ the `just tofu::*` recipes render a gitignored `tofu/topology.json` with `yq -p toml -o json`, decoded by `jsondecode`.
  Rejected — bare `tofu` would read a missing or stale file.
- _Alternative:_ keep `topology.yaml` for OpenTofu only.
  Rejected — it keeps the two-copy problem this change exists to remove.

### `tofu/topology.toml` stays a symlink

The `repo-layout` spec keeps repo-root data reachable from `tofu/` through symlinks; the existing symlink is renamed rather than replaced with a `../topology.toml` path, which would leave `${path.root}` for one file and not the other.

### Data parity first, deletion last

`da-n1x.public` is copied into `topology.toml` before any consumer switches, so each switch can be checked as a no-op against the unchanged YAML-era outputs, and `topology.yaml` is deleted only once nothing reads it.

### In-flight changes are updated in this change

Each in-flight change is edited only where it names `topology.yaml` or depends on how the topology is parsed; its scope, decisions, and task count are otherwise unchanged.

#### `talos-guest-clusters`

- **D4 and the proposal** read `topology.toml` through `lib.importTOML` instead of `topology.yaml` through `lib.rbn.from-yaml`, keeping the rationale ("the topology is where the router's VLANs are declared").
  D6's `from-yaml` reads of the HelmChart CRs are unchanged.
- **Task 3.2** looks the VLAN up in `topology.toml`; **task 3.9**'s assertion names `topology.toml`.
- **Task 5.1** adds `talos-waypoints` as a `[vlans.talos-waypoints]` table in `topology.toml` and verifies with `yq -p toml '.vlans["talos-waypoints"]' topology.toml`.
  It also extends `topology.schema.json`: the `vlan` definition is closed (`additionalProperties: false`), so the new `sites` key would otherwise be rejected by tombi and `check-jsonschema`.
  `sites` becomes an optional, unique, non-empty array of the `site` definition; the key `talos-waypoints` already matches `vlan-name`.
  The verification adds `tombi lint topology.toml` passing.

#### `tofu-per-site-modules`

- **Placement.** Its `tofu-root-module` spec gives `main.tofu` "provider requirements, provider blocks, sops reads" and `holonet.tofu` "the overlay catalog".
  The `toml` entry in `required_providers` is a provider requirement and stays in `main.tofu`; `data "toml_file" "topology"` and `local.topology` are the overlay catalog and stay in `holonet.tofu`.
  `tobotimus/toml` needs no `provider` block, so "provider blocks only in `main.tofu`" holds unchanged.
- **D10.** `data.sops_file.relay`'s `for_each = keys(local.topology.network)` now depends on a data source rather than `yamldecode`; the input is a literal file, so the keys remain known at plan time and D10 needs no change beyond naming the file.
- **Text.** Design lines naming `topology.yaml` (Context, Non-goals, and the `tofu/topology.yaml` symlink in the "not changed" list) and the `tofu-root-module` scenario "Adding a relay adds no data source" name `topology.toml`.

#### `docs-site-multi-domain`

Both changes MODIFY "Tool trees live at the repository root", and a MODIFIED block replaces the whole requirement on archive, so the second to archive must carry the first's edits.
The order is fixed: this change archives first, `docs-site-multi-domain` second, and the operator gates it.
This change's delta therefore describes only this change, and `docs-site-multi-domain`'s delta becomes a **superset** of it: its requirement sentence and its two path scenarios name `topology.toml`, it gains "No YAML copy of the topology remains", and it keeps all of its own `docs/` content.
Its archive then replaces the requirement with a block that already holds everything this change added.

- _Alternative:_ both deltas carry one identical block holding the union of both changes' content, so either can archive first.
  Rejected — with the order known it buys nothing, and it would make this change's archive assert the root `docs` justfile module and the self-contained docs build before `docs-site-multi-domain` delivers them.

## Risks / Trade-offs

- [`tobotimus/toml` decodes a value with a different type than `yamldecode` did — e.g. a tuple where a list was, or a number where a string was] → the `tofu plan` no-op check catches any resulting diff; quoted values (`zerotier.network`) are strings in both files.
- [The provider is abandoned or yanked] → it is pinned and hash-locked; replacing it is a two-line change in `holonet.tofu`, and the just-JSON alternative above remains available.
- [A host's toplevel `drvPath` cannot show the change is a no-op] → six of the seven hosts embed `inputs.self` (`configurationRevision` in `nixos-version`, the `self` entry in `/etc/nix/registry.json`, the store paths of `secrets/*.sops.yaml` in sops manifests), so any tree edit moves their `drvPath`.
  The no-op check instead compares the option values the topology feeds — k3s flags, ZeroTier networks, NFS exports, time servers, and the `wg-holonet` interface — at the pre-change revision and after.
- [`docs-site-multi-domain` archives before this change] → this change's later archive would drop the `docs/` sentence and its two docs scenarios; the operator gates the order, and the archive follow-up checks the main spec after `docs-site-multi-domain` archives.
- [An in-flight change is edited again after this change updates it and reintroduces `topology.yaml`] → task 7.4's `rg` sweep over `openspec/changes/` is rerun before archive.

## Migration Plan

1. Record each host's topology-derived option values (NixOS hosts, the darwin host, and `bootstrap`) and a `just tofu::plan` baseline that shows no changes.
2. Copy `da-n1x.public` into `topology.toml`.
3. Switch the Nix, OpenTofu, and justfile consumers; rename `tofu/topology.yaml` → `tofu/topology.toml`; run `tofu init` to fetch and lock the provider.
4. Re-check: identical topology-derived option values, `just tofu::plan` with no changes, `nix flake check`, and `just bootstrap mikrotik render` reading role and trunks.
5. Update rules, `AGENTS.md` files, and comments; delete `topology.yaml`.
6. Update the three in-flight changes' artifacts and validate each with `openspec validate --strict`.

Rollback is reverting the change's commits; nothing deployed changes, so no host or relay needs touching.
