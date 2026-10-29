# Tasks

## 1. Baseline

- [x] 1.1 Record, for every `nixosConfigurations.*` and `darwinConfigurations.*` output, the topology-derived option values (`services.k3s.extraFlags`, `services.zerotierone.joinNetworks`, `services.nfs.server.exports`, `networking.timeServers`, `networking.wg-quick.interfaces.wg-holonet`) at the pre-change revision into a scratch file outside the repo, and verify one record is written per host listed by `nix eval .#<kind> --apply builtins.attrNames`; toplevel `drvPath`s are not comparable, since six of the seven hosts embed `inputs.self` (`configurationRevision`, the `self` registry entry, sops-file store paths) and move on any tree edit
- [x] 1.2 Run `just tofu::plan` and verify it reports no changes before anything is edited; if it does not, stop and report the existing drift rather than continuing
- [x] 1.3 Record, for each relay in `network`, the output of `bootstrap/mikrotik/justfile`'s role and trunk `yq` expressions against `topology.yaml` into the same scratch file, and verify one role and one trunk line is recorded per relay

## 2. Data parity

- [x] 2.1 Copy `clients.da-n1x.public` from `topology.yaml` into `topology.toml`, and verify `diff <(yq -o json -P 'sort_keys(..)' topology.yaml) <(yq -p toml -o json -P 'sort_keys(..)' topology.toml)` shows only `network.da-relay02.uplink`
- [x] 2.2 Verify `tombi lint topology.toml` and `nix build .#checks.<system>.topology` both pass with the restored key

## 3. Nix consumers

- [x] 3.1 Replace `lib.rbn.from-yaml <self>/topology.yaml { inherit pkgs; }` with `lib.importTOML <self>/topology.toml` in `modules/services/kubernetes/kubernetes.nix`, `modules/services/zerotier.nix` (both call sites), `modules/services/nfs.nix`, and `modules/system/time.nix`, and verify `rg -n 'topology\.yaml' modules` matches only comments
- [x] 3.2 Collapse `wg-holonet.nix`'s `read-topology lib pkgs` helper into one `lib.importTOML` value and drop its IFD comment, and verify `rg -n 'read-topology|from-yaml' modules/system/networking/wg-holonet.nix` matches nothing
- [x] 3.3 Update the comments in `modules/services/zerotier.nix` and `modules/system/networking/wg-holonet.nix` that name `topology.yaml`, and verify `rg -n 'topology\.yaml' modules` matches nothing
- [x] 3.4 Re-evaluate the topology-derived option values from 1.1 in the working copy, and verify each host's record is identical to its baseline and populated where the host includes the consuming aspect; `wg-holonet` is included by no host, so its rewrite is covered only by `nix-instantiate --parse` and deadnix

## 4. OpenTofu

- [x] 4.1 Add `toml = { source = "tobotimus/toml", version = "0.3.0" }` to `required_providers` in `tofu/main.tofu`, run `just tofu::init`, and verify `.terraform.lock.hcl` gains a `registry.opentofu.org/tobotimus/toml` block at `0.3.0`
- [x] 4.2 Replace the `tofu/topology.yaml` symlink with a `tofu/topology.toml` symlink to `../topology.toml`, track it with `jj file track`, and verify `readlink tofu/topology.toml` prints `../topology.toml` and `jj diff --git tofu/topology.toml` records mode `120000`
- [x] 4.3 In `tofu/holonet.tofu`, add `data "toml_file" "topology"` reading `file("${path.root}/topology.toml")` and set `local.topology = data.toml_file.topology.content`, and verify `just tofu::plan` reports no changes
- [x] 4.4 Update `tofu/AGENTS.md` (the symlink list and the "same `topology.yaml` literal" note) to name `topology.toml` and the provider, and verify `rg -n 'topology\.yaml' tofu` matches nothing

## 5. Justfiles

- [x] 5.1 In `bootstrap/mikrotik/justfile`, point `topology` at `root / "topology.toml"`, add `-p toml` to both `yq` reads, and update the operator-workflow comment; verify that for each of `da-relay01`, `da-relay02`, and `en-relay01` the two `yq` expressions print the same role and trunk string against `topology.toml` as recorded in 1.3
- [x] 5.2 Verify `render` still refuses a missing role by running the role `yq` expression for a nonexistent relay against `topology.toml` and confirming it prints an empty string, which the recipe's guard rejects
- [x] 5.3 In `kubernetes/justfile`, point `topology` at `root / "topology.toml"` and update the "has no clients.… in topology.yaml" message, and verify `nu -c 'open topology.toml | get clients.da-vcx-1.ip'` prints `10.42.32.11`
- [x] 5.4 Update `bootstrap/AGENTS.md`, `kubernetes/AGENTS.md`, and the four "must track topology.yaml" comments under `kubernetes/clusters/*/flux/`, and verify `rg -n 'topology\.yaml' bootstrap kubernetes` matches nothing

## 6. Remove the YAML copy

- [ ] 6.1 Delete `topology.yaml` (`jj file untrack` is not needed — deleting a tracked file records the deletion), and verify `rg -n --hidden -g '!.direnv' -g '!.scratch' -g '!openspec/**' 'topology\.yaml' .` matches nothing
- [ ] 6.2 Run `nix flake check` and `just tofu::plan`, and verify both succeed with `just tofu::plan` reporting no changes

## 7. In-flight changes

- [ ] 7.1 Update `talos-guest-clusters` per `design.md` ("`talos-guest-clusters`"): `proposal.md` (the VLAN bullet and the Impact list) and D4 in `design.md` (including the `vlan` field description) name `topology.toml` read through `lib.importTOML`; task 3.2 looks the VLAN up in `topology.toml` through `lib.importTOML`; task 3.9's assertion names `topology.toml`; task 5.1 adds a `[vlans.talos-waypoints]` table to `topology.toml`, extends `topology.schema.json`'s `vlan` definition with an optional unique non-empty `sites` array of `site`, and verifies with `yq -p toml '.vlans["talos-waypoints"]' topology.toml` and `tombi lint topology.toml`; leave D6's `from-yaml` reads of the HelmChart CRs untouched; verify `rg -n 'topology\.yaml' openspec/changes/talos-guest-clusters` matches nothing, `rg -n 'from-yaml' openspec/changes/talos-guest-clusters` matches only D6, and `openspec validate talos-guest-clusters --strict` passes
- [ ] 7.2 Update `tofu-per-site-modules` per `design.md` ("`tofu-per-site-modules`"): its `design.md` Context, Non-goals, and "not changed" symlink list, and the `tofu-root-module` scenario "Adding a relay adds no data source", name `topology.toml`; add to its D1 or D10 that `data "toml_file" "topology"` and `local.topology` stay in `holonet.tofu` while the `toml` provider requirement stays in `main.tofu` with no `provider` block; verify `rg -n 'topology\.yaml' openspec/changes/tofu-per-site-modules` matches nothing and `openspec validate tofu-per-site-modules --strict` passes
- [ ] 7.3 Make the "Tool trees live at the repository root" block in `openspec/changes/docs-site-multi-domain/specs/repo-layout/spec.md` a superset of this change's block: name `topology.toml` in its requirement sentence and in the "Nix reads repo data files from root-relative paths" and "Relative paths into the repo root keep their target" scenarios, and append this change's "No YAML copy of the topology remains" scenario, keeping all of its `docs/` content; verify that a `diff` of the two extracted requirement blocks shows only the `docs/` sentence fragment, the `docs` justfile-module scenario lines, and the "Documentation site is self-contained under docs" scenario, and that `openspec validate docs-site-multi-domain --strict` passes
- [ ] 7.4 Verify `rg -n 'topology\.yaml' openspec/changes --glob '!archive/**' --glob '!topology-toml/**'` matches nothing, and rerun it immediately before archiving this change

## Workflow follow-up

- Archive this change with `/openspec-archive-change` once the tasks are done, and before `docs-site-multi-domain`; then verify `openspec/specs/{repo-layout,bootstrap}/spec.md` name `topology.toml`.
- After `docs-site-multi-domain` archives, verify "Tool trees live at the repository root" in `openspec/specs/repo-layout/spec.md` names both `docs/` and `topology.toml` and still has the "No YAML copy of the topology remains" scenario.
