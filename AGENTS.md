# AGENTS.md — The Rebellion Homelab

Agent guidance for "The Rebellion", a Nix-based homelab. This file holds only
repo-wide identity, policy, and the index — domain knowledge lives in
directory-level `AGENTS.md` files linked into `.agents/rules/`, not here.

## What this repo is

- **den** (`github:denful/den`) — aspect-oriented, feature-first layer above
  NixOS / nix-darwin / Home Manager, under the custom namespace `rbn`. This is
  NOT traditional per-host NixOS organization → `src/modules/AGENTS.md`.
- **flake-parts** with `import-tree` auto-discovery; `flake-file` regenerates
  `flake.nix` from `flake-file.inputs` declarations colocated with consumers.
- **K3s + Flux GitOps** for containers → `src/kubernetes/AGENTS.md`.
- **OpenTofu** for network/SaaS infra → `src/terraform/AGENTS.md`.
- **sops + age** for secrets (host-SSH-derived identities).
- Multi-site: `da` (Dantooine) datacenter live, `en` (Endor) emerging. Hosts
  are named `<site>-<node>` (e.g. `da-vcx-1`).

## Essential commands

```bash
nix fmt              # format everything (treefmt)
nix flake check      # validate the flake
just --list          # task runner — check here before improvising commands
just tofu-plan       # OpenTofu (wrapped: -parallelism=1 -compact-warnings)
nh os switch / nh darwin switch   # rebuild helper
```

## Agent documentation layout

Domain knowledge lives **next to the code it describes**, in directory-level
`AGENTS.md` files, each scoped by a `paths:` glob in its frontmatter. This file
holds only repo-wide identity, policy, and the index.

Harnesses disagree on what they load, so every rule has one source and one
link:

| Harness                      | Reads                                                                                                           |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Codex, opencode, Antigravity | `AGENTS.md` per directory as they descend; `.agents/rules`, `.agents/skills`                                    |
| Claude Code                  | `CLAUDE.md` (a symlink to this file); `.claude/rules` and `.claude/skills`, themselves symlinks into `.agents/` |

**Claude Code does not read `AGENTS.md` at all**, so each directory-level file
is symlinked into `.agents/rules/<name>.md`. Cross-cutting rules that belong to
no single directory (`den-style.md`, `nix-style.md`) are plain files in
`.agents/rules/`. Repo-scoped skills are directories under
`.agents/skills/<name>/SKILL.md`. Everything under `.agents/` and `.claude/` is
tracked and hand-maintained — nothing generates it.

Adding a rule: write `<dir>/AGENTS.md` with `paths:` frontmatter, add a
relative symlink to it at `.agents/rules/<name>.md` (see `ai-tools.md` for the
shape), and `jj file track` both. A rule without a link is invisible to Claude;
a link without frontmatter loads into every session.

### Writing a rule

1. **A fact lives in exactly one file** — the rule whose `paths:` glob covers
   its subject. No restating across rules.
2. **Scope with `paths:`.** A rule with no frontmatter loads into _every_
   session and must earn that cost. Only genuinely repo-wide style belongs
   there.
3. **Verify the glob resolves** before committing. A glob matching nothing is
   the husk failure mode, and it is silent.
4. Rules are for durable structure and constraints — not for "currently
   broken" notes, which rot the moment they are fixed.

### Link status

Every non-empty `AGENTS.md` has `paths:` frontmatter and a link in
`.agents/rules/`. Link names carry a domain prefix — `nix-` for `src/modules`,
`kubernetes-` for `src/kubernetes`, `tofu` for `src/terraform` — then the
directory path joined with `-` (`src/modules/_lib` → `nix-lib.md`,
`src/kubernetes/components/syncthing` → `kubernetes-syncthing.md`). Two empty
husks are unlinked for now: `src/AGENTS.md` and
`src/kubernetes/apps/kube-system/zfs-localpv/AGENTS.md`. Other `src/*` children
(`bootstrap/`, `homelab/`, `mikrotik/`, `vault/`) are a mixture of live tooling
and unflagged dead code — do not assume either way without checking.

### Comments vs rules (two-phase policy)

While drafting, comment freely — inline comments are cheap working memory and
improve generation. They are **not** free to keep. Before committing, sweep
every comment you added:

- **Load-bearing at that exact line** — an action marker ("DELETE this line
  once …", "STAGED — needs X first") or a constraint a naive edit at that
  spot would silently violate → keep it.
- **Anything else** — rationale, architecture, cross-file wiring, operational
  context → lift it into the rule whose `paths:` glob covers that file (merge
  with what's already there, don't append duplicates), then delete the
  comment.

The sweep's criterion is load-bearing-ness, not zero comments — a comment
that prevents a bad future edit at that line stays, however prose-y it looks.

Never create a rule _just_ to have somewhere to lift a comment — widen an
existing rule's glob, or lift into the rule that already governs the area. A
sweep that keeps surfacing context for a path no rule covers is the signal to
deliberately architect one.

## Quality gates

- `nix fmt` before committing; hooks enforce sops encryption, nix syntax, and
  formatting.
- Test builds without switching:
  `nixos-rebuild build --flake .#<hostname>` (or `nix build
.#nixosConfigurations.<hostname>.config.system.build.toplevel`).
- Conventional Commits, signed.

## External references

- **den** — `github:denful/den` (aspects/schema/ctx/provides model)
- **home-ops** (onedr0p) — primary K8s reference; **cluster-template** —
  architectural inspiration
- **flake-parts**, **import-tree**, **flake-file** — flake composition
