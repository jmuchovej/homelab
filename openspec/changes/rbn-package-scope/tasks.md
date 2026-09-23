## 1. Preconditions (worktree)

- [x] 1.1 Confirm `flatten-src-tree` has landed on the base of this worktree: `ls modules/_overlays modules/system/fonts` succeeds and `ls src` shows only `homelab`; if not, stop and either rebase or apply the two path deltas noted in design.md (one extra parent-directory hop in the overlay path, `src/modules/…` in the `AGENTS.md` paths)
- [x] 1.2 Copy `packages/` from the main checkout (`/Users/john/Homelab`) into the worktree, then `jj file track packages`; verify `jj file list packages | rg -c 'package.nix$'` prints `24`, `ls packages/fonts` shows `albert-sans`, `brandon-text`, `monolisa` (each as a flat `<name>.nix` plus a `<name>/` directory of font files), and `diff -rq packages /Users/john/Homelab/packages` is silent
- [x] 1.3 Record the pre-change baseline: `nix eval .#nixosConfigurations.da-vcx-2.config.fonts.packages --apply 'map (p: p.pname)'` and the same for `.#darwinConfigurations.da-n1x` (expect the darwin list to lack the three repo fonts), plus `nix flake show --json | yq -p json '.overlays'` (expect `contrib`); save to a scratch note for 6.x

## 2. Restructure the packages tree (worktree)

- [x] 2.1 Rename the 17 parked directories with a `_` prefix: the stubs `affinity`, `brave-browser`, `claude-desktop`, `google-chrome`, `proton-pass-cli`, `proton-pass`, `proton-vpn-cli`, `proton-vpn`, `setapp`, `sketch`, `superwhisper`, `vivaldi`, `waypoints`, `zen-browser`, `no-tunes`, plus `notion-app` and `notion-calendar` (each reads a `source.json` that was never committed, so they throw at evaluation); verify `find packages/by-name -name package.nix -not -path '*/_*' | wc -l` prints `7` and every remaining `package.nix` is more than one line
- [x] 2.2 For each of `brandon-text` and `monolisa` (`albert-sans` has never had font files in the repo, so its builder is parked as `packages/fonts/_albert-sans/` until it is packaged from upstream): create `packages/fonts/<name>/package.nix` from `modules/system/fonts/_packages/<name>.nix` with `src = ./_files;` and move the font files into `packages/fonts/<name>/_files/`; delete the flat `packages/fonts/<name>.nix` and any remaining `packages/fonts/<name>/*.otf|*.ttf|*.woff2` at the top level; verify `find packages/fonts -name package.nix | wc -l` prints `3`, `find packages/fonts -maxdepth 2 -name '*.nix' -not -name package.nix` is empty, and each `_files/` has the same file count as the source directory it came from
- [x] 2.3 Delete `modules/system/fonts/_packages/`; verify `ls modules/system/fonts` shows only `fonts.nix` and `jj st` lists the deletions as moves into `packages/fonts/`

## 3. Overlay (worktree)

- [x] 3.1 Write `modules/_overlays/rbn.nix` as `{ inputs }: final: _prev:` per design D1–D7: a `scopeFrom root newScope` helper that pipes `inputs.import-tree` through `.filter (lib.hasSuffix "/package.nix")`, `.map` to `nameValuePair (baseNameOf (dirOf p)) p`, `.leaves root`, groups by name and throws listing both paths on any duplicate, then `lib.makeScope newScope (self: mapAttrs (_: p: self.callPackage p { }) files)`; the two roots are `packages/by-name` and `packages/fonts` reached by two parent-directory hops from the overlay file; return `{ rbn = … }` with `fonts = scopeFrom <fonts-root> final.rbn.newScope` inside the `rbn` fixed point; verify `nix eval .#nixosConfigurations.da-vcx-2.pkgs.rbn --apply 'r: builtins.attrNames (r.packages r)'` lists exactly the 7 real names plus `fonts`, and the same against `pkgs.rbn.fonts` lists `brandon-text monolisa`
- [x] 3.2 Edit `modules/overlays.nix`: remove `contrib-dir`, `contrib-overlays`, the `pathExists` import, and the `++ [ contrib-overlays ]`; replace `flake.overlays.contrib` with `flake.overlays.rbn = import ./_overlays/rbn.nix { inherit inputs; };`; verify `nix flake show --json | yq -p json '.overlays | keys'` prints `[rbn]` and `nix eval .#nixosConfigurations.da-vcx-2.pkgs --apply 'p: p ? contrib'` prints `false`
- [x] 3.3 Prove the resolution order: `nix eval .#nixosConfigurations.da-vcx-2.pkgs --apply 'p: p.rbn.beeper.meta.position != p.beeper.meta.position'` prints `true` (top level untouched; `drvPath` would trip the unfree gate on nixpkgs' `beeper`), and `nix eval .#nixosConfigurations.da-vcx-2.pkgs.rbn --apply 'r: r.callPackage ({ jj-hooks, rustPlatform }: jj-hooks.pname + "/" + builtins.typeOf rustPlatform) { }'` prints `"jj-hooks/set"` (sibling then nixpkgs); the same call against `pkgs.rbn.fonts` with `({ monolisa, jj-hooks, stdenv }: …)` succeeds (fonts, then rbn, then nixpkgs)
- [x] 3.4 Prove the duplicate guard: temporarily add `packages/by-name/zz/jj-hooks/package.nix` as a copy, run the 3.1 eval and verify it throws a message naming both `jj/jj-hooks` and `zz/jj-hooks`; remove the copy and verify the eval passes again
- [x] 3.5 Prove the stub skip and full-scope evaluation: `nix eval .#nixosConfigurations.da-vcx-2.pkgs --apply 'p: map (n: p.rbn.${n}.name) (builtins.attrNames (p.lib.filterAttrs (_: p.lib.isDerivation) p.rbn))'` returns 7 names with no throw, and `--apply 'p: p.rbn ? affinity'` prints `false`

## 4. Fonts aspect (worktree)

- [ ] 4.1 In `modules/system/fonts/fonts.nix`, replace the three `callPackage ./_packages/…` bindings and their list entries with `(lib.filter lib.isDerivation (lib.attrValues pkgs.rbn.fonts))` prepended to `fonts.packages`; convert the `macos` attribute set to `{ lib, pkgs, ... }:` and add `fonts.packages = lib.filter lib.isDerivation (lib.attrValues pkgs.rbn.fonts);` beside the existing Homebrew cask list; verify `rg -n '_packages|callPackage' modules/system/fonts` is empty
- [ ] 4.2 Verify both host classes see the fonts: the two `fonts.packages` evals from 1.3 now include `brandon-text`, `monolisa` on `da-vcx-2` and on `da-n1x`, and contain no non-derivation entries (`--apply 'l: builtins.all (x: x ? drvPath) l'` prints `true`)

## 5. Docs and comment sweep (worktree)

- [ ] 5.1 Rewrite `modules/_overlays/AGENTS.md`: keep its `paths:` frontmatter and widen the glob to cover both `modules/_overlays/**` and `packages/**` (the link `.agents/rules/nix-overlays.md` already exists, so no new link is needed); keep the wire-only-here invariant and the two overlay forms; replace the "Overlay vs package" section with the `packages/` contract (by-name shard layout, `package.nix`-only discovery, `_` parking, `pkgs.rbn` fixed point with sibling-before-nixpkgs resolution, `pkgs.rbn.fonts` nested with fonts-then-rbn-then-nixpkgs resolution, `lib.isDerivation` filter when consuming a scope); verify `rg -n contrib modules/_overlays/AGENTS.md` is empty and the frontmatter still parses
- [ ] 5.2 Rewrite `modules/_overlays/_packages/AGENTS.md` to describe only what remains there (`installer.nix`, repo-specific derivations wired explicitly) and point novel upstream-shaped packages at `packages/by-name/`; verify `rg -n 'contrib|packagesFromDirectoryRecursive' modules` is empty
- [ ] 5.3 Sweep comments added during 3.x and 4.x per the root `AGENTS.md` two-phase policy: keep only line-local action markers or constraints a naive edit would violate; lift the rest into 5.1; verify by reading the diff of `rbn.nix`, `overlays.nix`, and `fonts.nix`

## 6. Gates (worktree)

- [ ] 6.1 Run `nix fmt` (or `jj fix`) and verify `jj diff --stat` shows no formatting-only churn outside the files touched in 2.x–5.x
- [ ] 6.2 Run `nix flake check` and verify it passes; run `prek run --all-files` (or the installed pre-commit) and verify all hooks pass
- [ ] 6.3 Build the fonts and one free package for both systems: `nix build .#nixosConfigurations.da-vcx-2.pkgs.rbn.fonts.{brandon-text,monolisa} .#nixosConfigurations.da-vcx-2.pkgs.rbn.jj-hooks` and the same three under `.#darwinConfigurations.da-n1x.pkgs.rbn…`; verify each font result contains `share/fonts/truetype/` with the expected `.otf`/`.ttf` files
- [ ] 6.4 Evaluate every host that evaluated in the `flatten-src-tree` baseline (`da-gr75`, `da-vcx-2`, `da-vcx-3`, `da-n1x`) with `nix eval …config.system.build.toplevel.drvPath` and verify each succeeds; inspect `nix derivation show` on one font and confirm the only input change is the `_files` source path
- [ ] 6.5 Run `nix build .#darwinConfigurations.da-n1x.system` and verify it succeeds and its fonts activation references the three repo fonts

## 7. Commit (worktree)

- [ ] 7.1 Describe the change as one signed conventional commit (`feat(packages)!: expose packages/ as the pkgs.rbn scope, drop pkgs.contrib`) whose body records the sibling-before-nixpkgs resolution order and the `_` parking convention; verify `jj log -r @` shows a single change containing the tree moves, the overlay, the fonts aspect edit, and the two `AGENTS.md` rewrites

## 8. Cutover in the main checkout (after the change lands there)

- [ ] 8.1 Update the main checkout to the landed change and remove the now-duplicated untracked files it still carries: `packages/fonts/<name>.nix`, the top-level `packages/fonts/<name>/*.otf|ttf|woff2`, and the un-renamed stub directories; note the main checkout's working-copy change currently snapshots 246 unrelated files (docs, wallpapers), so untrack or split those deliberately rather than committing them with this cutover; verify `jj st` is clean for `packages/` and `find packages -name package.nix -not -path '*/_*' | wc -l` prints `9` (7 apps + 2 fonts)
- [ ] 8.2 `nh darwin switch` on `da-n1x` and verify `ls "/Library/Fonts/Nix Fonts"` lists Brandon Text and MonoLisa files
- [ ] 8.3 On the next routine NixOS rebuild of any host, verify `fc-list | rg -i 'brandon|monolisa'` shows both families (no separate rollout needed)
