## 1. Baseline (worktree)

- [x] 1.1 Record the pre-move Nix baseline: run `nix flake show` and `nix eval` of `toplevel.drvPath` for the NixOS hosts without the server aspect (`da-gr75`, `da-vcx-2`, `da-vcx-3`) and for the darwin host `da-n1x` under `darwinConfigurations`, plus `nix build .#checks.<system>.den-tests`; note which succeed so 6.x compares like for like (the `bootstrap` host is expected to fail on the missing `secrets/keys/iso-key.pub`)
- [x] 1.2 Record the pre-move reference inventory: `rg -n 'src/' --glob '!vendor/**' --glob '!*.lock' --glob '!openspec/**'` count and file list, saved to a scratch note, so 5.1 can confirm every hit was handled
- [x] 1.3 Snapshot both clusters before anything merges: `kubectl get helmreleases -A` and per-namespace pod counts saved to the scratch note, so 9.6 has a baseline to compare against

## 2. Move the trees (worktree)

- [x] 2.1 `jj`/`git mv` `src/modules` to `modules`, `src/kubernetes` to `kubernetes`, `src/mikrotik` to `mikrotik`, `src/terraform` to `tofu`, `src/topology.yaml` to `topology.yaml`; verify `ls src` shows only `homelab`
- [x] 2.2 Re-link `tofu/secrets` (one directory up) and `mikrotik/bootstrap/secrets` (two directories up); leave the three `topology.yaml` links as-is (`tofu/`, `mikrotik/bootstrap/`, `modules/system/networking/`); verify `readlink` on all five resolves to an existing file and `sops -d tofu/secrets/secrets.sops.yaml >/dev/null` succeeds

## 3. Rewrite tracked references (worktree)

- [x] 3.1 `modules/inputs.nix`: change `flake-file.outputs` to `import-tree ./modules` and update the comment; run `just regen` and verify `flake.nix` line 5 reads `./modules` and `git diff flake.nix` shows only that line
- [x] 3.2 Root `justfile`: update the three `mod` paths to `modules/hosts/bootstrap/justfile`, `tofu/mikrotik.just`, `tofu/authentik.just` and the `facter` recipe's `dir` to `modules/hosts/{{ host }}`; verify `just --list` and `just bootstrap --list`, `just mikrotik --list`, `just authentik --list` all succeed
- [x] 3.3 Nix `inputs.self` paths: `kubernetes.nix` (`bootstrap/kubernetes`, `topology.yaml`), `zerotier.nix` (both `topology.yaml`), `talos.nix` (`bootstrap/talos/machineconfig.yaml`), `nix-builders.nix` (`modules/hosts/${host}/facter.json`); verify `rg 'inputs.self.*src/|self}/src/' modules` returns nothing. Relative path: `hosts/bootstrap/bootstrap.nix`, both `fileContents` calls for `secrets/keys/iso-key.pub`, drop from four parent-directory hops to three; verify `rg -n 'fileContents \.\.' modules/hosts/bootstrap` shows three hops on both lines
- [x] 3.4 Flux Kustomization paths: rewrite `path: ./src/kubernetes/` to `path: ./kubernetes/` across `kubernetes/**/*.ks.yaml`; verify `rg -c 'path: ./kubernetes/' kubernetes | wc -l` equals the 59 counted in 1.2 and `rg 'src/kubernetes' kubernetes` is empty
- [x] 3.5 Tooling patterns: `.envrc` `watch_file modules/devshell/*.nix`; `.gitignore` `!kubernetes/clusters/**/*.pub`; `.sops.yaml` two cluster `path_regex` values to `kubernetes/clusters/...`; `modules/devshell/checks.nix` `files` and three `excludes` regexes to `^kubernetes/`; `.zed/settings.json` every `./src/kubernetes/**` glob to `./kubernetes/**`; `rules/ai-tools.md` `paths:` glob to `modules/ai-tools/**`; verify `rg 'src/' .envrc .gitignore .sops.yaml .zed rules modules/devshell` is empty
- [x] 3.6 `modules/services/kubernetes/justfile`: `bootstrap/kubernetes` and `bootstrap/talos/machineconfig.yaml`; verify by reading the two `manifests=`/`talos_image=` lines
- [x] 3.7 Comments, AGENTS.md headings, and `.tofu` strings: `modules/AGENTS.md`, `kubernetes/AGENTS.md`, `kubernetes/clusters/AGENTS.md`, `kubernetes/components/cnpg-import/AGENTS.md` (prefix only; the cited `postgres.nix` does not exist), `modules/secrets/AGENTS.md`, `modules/services/kubernetes/AGENTS.md` and `kubernetes.nix` comment, `rules/ai-tools.md` heading, `zerotier.nix`, `wg-holonet.nix` (fix to `topology.yaml`), `da-gr75.nix`, `tofu/ak.variables.tofu`, `tofu/mikrotik/users.tofu` (fix to `mikrotik/bootstrap/justfile`), `kubernetes/apps/network/cloudflare-tunnel/app/external-secret.yaml`, `kubernetes/apps/media/recyclarr/app/resources/recyclarr.yml`; verify `rg -n 'src/(modules|kubernetes|terraform|mikrotik|bootstrap|topology)' --glob '!vendor/**' --glob '!openspec/**'` is empty

## 4. Format and hooks (worktree)

- [x] 4.1 Run `nix fmt` and verify `git diff --stat` shows no formatting-only churn beyond the files touched in 3.x
- [x] 4.2 Run `prek run --all-files` (or the installed pre-commit) and verify `ensure-sops`, `treefmt`, and `check-k8s-schemas` pass and that `check-k8s-schemas` reports files under `kubernetes/`, not zero files

## 5. Reference sweep (worktree)

- [x] 5.1 Diff the `src/` inventory from 1.2 against the post-change grep; verify the only remaining `src/` hits are `src/homelab`, `vendor/**`, `uv.lock`, the generic examples under `modules/ai-tools/skills/**` and `modules/ai-tools/commands/**`, the `~/Documents/src/...` home paths in `modules/programs/terminal/{jujutsu.nix,jj-clone-forge.nu,topgrade.nix}`, and the upstream URL in `modules/programs/development/data/toml.nix`
- [x] 5.2 Verify `.github/workflows/flux-local.yaml` was not modified (pre-existing `flux/cluster` mismatch, out of scope) and note it in the change description

## 6. Nix and Flux gates (worktree)

- [x] 6.1 Re-run every command from 1.1 and verify the same set succeeds with identical `drvPath` output for each host that evaluated before
- [x] 6.2 Run `nix develop --command true` and verify the dev shell builds and the shell hook recreates `.agents/skills` and `.claude/skills`
- [x] 6.3 Build both Flux roots offline: `flux-local build ks --path kubernetes/clusters/da.jm0.io/flux` and the same for `en.jm0.io` (or `kustomize build` on each root and child path); verify every `spec.path` resolves and output is non-empty
- [x] 6.4 Run `nix-unit`/`just test` if present and verify den tests pass

## 7. Commit (worktree)

- [x] 7.1 Describe the change as a single signed conventional commit (`refactor(repo)!: flatten src/ into root-level trees, rename terraform to tofu`) with the Flux and tofu cutover notes in the body; verify `jj log -r @` shows one change containing all moves and rewrites

## 8. Cutover in the main checkout (after the change lands there)

- [x] 8.1 Move untracked tofu files into `tofu/`: `terraform.tfstate` and its three backups, `.terraform/`, `authentik.auto.tfvars.json`, `.scratch/`, and `da.cloudflare-tunnel.tofu`; verify `ls -a src/terraform` no longer exists and `ls -a tofu` lists them
- [x] 8.2 Run `tofu plan` inside `tofu/` and verify it reports no changes and no init is required
- [x] 8.3 Move the whole `src/bootstrap/` tree to `bootstrap/` (today only `talos/machineconfig.yaml`, plus any work-in-progress `kubernetes/` files) and verify `src/bootstrap` no longer exists and `src/` contains only `homelab`
- [x] 8.4 If `bootstrap/kubernetes/flux-instance.yaml` exists, set its sync path to `kubernetes/clusters/${dc-domain}/flux` (whatever placeholder `kubernetes.nix` renders for `dc-domain`) and verify `rg 'src/' bootstrap` is empty; if it does not exist, verify the 7.1 commit body records that the file must carry the new path when written
- [x] 8.5 Run `direnv allow` and verify the shell loads and `just --list` works from the main checkout

## 9. Flux cutover (both clusters, immediately after the change is on `main`)

- [x] 9.1 Read each cluster's live `FluxInstance` (`kubectl get fluxinstance -n flux-system -o yaml`) and verify `spec.sync.path` is `src/kubernetes/clusters/<dc-domain>/flux`; if it differs, stop and reconcile the design before changing anything
- [x] 9.2 Verify the prune invariant on the merged commit: `kubernetes/clusters/<dc-domain>/flux/` for both clusters contains exactly `cluster-config.ks.yaml` and `cluster-apps.ks.yaml`, no `kustomization.yaml`, and `metadata.name` in each is unchanged (`git diff <pre>..<post> --stat -- '*/flux/'` shows renames only)
- [x] 9.3 Optional: `flux suspend kustomization cluster-config cluster-apps -n flux-system` on both clusters to silence errors during the window; verify `flux get kustomizations -A` shows both Suspended
- [x] 9.4 Apply the new sync path on both clusters: preferred route is rebuilding the server nodes if `flux-instance.yaml` from 8.4 is deliverable; otherwise `kubectl patch fluxinstance flux -n flux-system --type merge -p '{"spec":{"sync":{"path":"kubernetes/clusters/<dc-domain>/flux"}}}'` (confirm the object name from 9.1); verify `kubectl get fluxinstance -n flux-system -o jsonpath='{.items[0].spec.sync.path}'` prints the new path on each cluster
- [x] 9.5 `flux reconcile source git flux-system -n flux-system` on both clusters, resume the roots if 9.3 was used, and verify `flux get kustomizations -A` shows `flux-system`, `cluster-config`, and `cluster-apps` Ready at the merged revision for both `da.jm0.io` and `en.jm0.io`
- [x] 9.6 Verify nothing was pruned: `flux events -A --for Kustomization/cluster-apps` and `kubectl get helmreleases -A` show no deletions or reinstalls, and pod counts per namespace match the pre-merge snapshot

## 10. Post-cutover checks (main checkout)

- [x] 10.1 Verify `just mikrotik list-interfaces <target>` and `just authentik discover-flows` each resolve their sops files (a non-error response proves the `secrets` symlink and module cwd are correct)
