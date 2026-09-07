---
name: flake-brief
description: Analyze an uncommitted flake.lock bump - diff watched inputs between old and new revs, intersect upstream changes with repo usage, and emit a transition/breakage brief. Use after `just update` (or any flake.lock bump) before switching; runs headless via `claude -p "/flake-brief"` with stdout as the brief.
disable-model-invocation: true
allowed-tools:
  - Read(//nix/store/**)
  - Read(flake.lock)
  - Read(flake.nix)
  - Read(src/modules/**)
  - Read(**/AGENTS.md)
  - Read(.agents/rules/**)
  - Bash(git show *)
  - Bash(git diff *)
  - Bash(nix flake prefetch *)
  - Bash(gh api *)
  - Bash(diff *)
  - Bash(rg:*)
---

# flake-brief — lock-bump transition analysis

You are analyzing an **uncommitted** `flake.lock` bump. You are read-only: do
NOT edit, write, restamp, or fix anything — your **final response IS the
brief** (headless runs redirect stdout to `.scratch/update-briefs/`). Report;
a human acts.

## Watched inputs

Only these structural inputs warrant analysis (skip leaf/package inputs
unless asked): `den`, `flake-file`, `import-tree`, `flake-parts`,
`home-manager`, `nix-darwin`, `sops-nix`, `nixpkgs` (major/channel moves
only, not routine bumps).

`den` gets the deepest treatment: it evolves fast, post-dates common model
knowledge, and this repo's den docs encode experiment-derived workarounds
that upstream may silently obsolete.

## Procedure

1. **Diff the lock**: `git diff HEAD -- flake.lock` (old = `git show
HEAD:flake.lock`, new = working tree). Collect `(input, owner, repo,
old-rev, new-rev)` for each changed watched input. If none changed, say so
   in one line and stop.
2. **Materialize both revs**: `nix flake prefetch
'github:<owner>/<repo>/<rev>' --json` — the returned `storePath` is the
   source tree (named `<hash>-source`; the JSON is the only way to identify
   it — never guess store paths).
3. **Upstream intent**: `gh api repos/<owner>/<repo>/compare/<old>...<new>`
   for the commit list; read messages for breaking-change markers, renames,
   deprecations.
4. **API surface diff**: `diff -r` the two store paths (focus: exported
   names, module options, function signatures, README/docs deltas). This is
   ground truth; commit messages are only hints.
5. **Intersect with this repo**: for every changed/renamed/removed symbol,
   `rg` `src/modules/` for call sites. A change without a call site is
   noise; a change WITH one is a finding — cite `file:line`.
6. **Check the contract** (den only): read `.agents/rules/den-style.md` —
   the den stamp and the "Invariants (hard-won)" section. For each
   invariant, judge from the upstream diff whether the bump could affect it,
   in either direction: a breakage, OR an upstream fix that obsoletes a
   documented workaround (flag these explicitly — stale workarounds become
   cargo cult).

## Brief format

Lead with a one-paragraph verdict: safe / needs attention / blocking, and
why. Then, per input, only the sections that have content:

- **Transitions** — renames, deprecations, behavioral changes relevant here
- **Likely breakages** — with repo `file:line` and the upstream commit/sha
- **Workarounds possibly obsoleted** — invariant ↔ upstream change pairs
- **Invariants to re-verify** — which, and the cheapest verification (e.g.
  "eval da-vcx-1 toplevel", "check overlay recursion by …")
- **Doc actions** — restamp `.agents/rules/den-style.md` to `<new-rev>`
  after verification; den-style claims now wrong (quote them)

Omit empty sections. No preamble about what you did — findings only.
