# AGENTS.md — The Rebellion Homelab

Agent guidance for "The Rebellion", a Nix-based homelab. This file holds only
repo-wide identity, policy, and the index — domain knowledge lives in the
path-scoped rules under `rules/`, not here.

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

Domain knowledge lives in **`rules/*.md`** at the repo root — one flat,
reviewable set, each file scoped by a `paths:` glob in its frontmatter. This
file holds only repo-wide identity, policy, and the index.

Why one directory rather than per-directory `AGENTS.md`: **Claude Code does not
read `AGENTS.md` at all** (it reads `CLAUDE.md` and `.claude/rules/`), so the
scattered files rotted unread — three husks in a row proved it. A flat set can
be audited in one sitting; a glob that stops matching is a visible defect.

### Source trees no agent loads

`rules/` and `skills/` sit at the repo root **precisely because nothing reads
them there**. That is what makes them a source rather than a copy: the devshell
renders each into the shape a given harness wants and links the result, so a
rule is loaded exactly once, and a harness needing a different dialect gets a
transform instead of a second hand-maintained file.

Wiring lives in `src/modules/devshell/shells.nix`; everything it produces is
gitignored generated output.

| Harness            | Reads                   | Produced by                  |
| ------------------ | ----------------------- | ---------------------------- |
| Antigravity, Codex | `.agents/rules`         | devshell ← `rules/`          |
| Claude Code        | `.claude/rules`         | devshell → `.agents/rules`   |
| Claude Code (root) | `CLAUDE.md`             | one-line `@AGENTS.md` import |
| Codex, opencode, … | `AGENTS.md` (this file) | root index, hand-written     |

Adding a rule takes two steps: **`jj file track rules/<name>.md`**, then
re-enter the shell (`nix develop`, or let direnv do it). The derivation is built
from the flake source, which is the _git tree_ — an untracked rule renders as
nothing, silently — and the links themselves are only refreshed by the shell
hook.

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

### Migration status

`src/modules/ai-tools/` is done (`rules/ai-tools.md`). Still per-directory
`AGENTS.md`, pending their own passes: `src/modules/` and its children,
`src/kubernetes/`, `src/terraform/`. Other `src/*` children (`consul/`, `nomad/`,
`vault/`, `mikrotik/`, `bootstrap/`, `homelab/`, `packages/`) are a mixture of
live tooling and unflagged dead code — do not assume either way without checking.

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
