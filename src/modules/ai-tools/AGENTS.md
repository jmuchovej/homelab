---
paths:
  - "src/modules/ai-tools/**"
---

# Authoring AI-tool config (`src/modules/ai-tools/`)

## Scope trap: this is `$HOME`, not this repo

These aspects build the **user's global agent config** — `~/.claude/`,
`~/.gemini/`, `~/.agents/skills/` — through home-manager. Nothing here
configures agents _for the Rebellion repo_.

Repo-scoped agent instructions live in `rules/*.md` at the repo root (this
file's own tree), which the devshell renders and links into each harness. If the
guidance you are about to write is "when working in this repo, do X", it does
not belong in this directory.

## Layout

One file per harness, each defining `rbn.programs._.ai-tools._.<harness>` with
`_.cli` and `_.desktop` sub-aspects:

| File           | Aspect                         |
| -------------- | ------------------------------ |
| `claude.nix`   | `…_.claude` — Claude Code      |
| `gemini.nix`   | `…_.gemini` — Antigravity CLI  |
| `codex.nix`    | `…_.codex` — Codex CLI         |
| `ai-tools.nix` | `…_.mcp`, `…_.skills` (shared) |

`ai-tools.nix` also carries the `flake-file.inputs` declarations and the
class-level `den.default.homeManager.imports` for `mcp-servers` — den does not
honour `imports` on an aspect, so that module has to be imported at class level
for its options to exist.

**`_`-prefixed paths are skipped by auto-discovery** and imported explicitly:
`_lib.nix`, `_system-prompt.md`, `_claude/`. This is the same role `.part.nix`
plays elsewhere in the tree.

`_system-prompt.md` is one shared global system prompt: Claude takes it as
`context`, Antigravity as `context.GEMINI`.

## The four content trees

All four are markdown walked by `import-tree` helpers in `_lib.nix`.
`initFilter` **must** be overridden in each — import-tree's default filter
admits only `.nix`, and these trees are `.md`.

### `commands/<category>/<name>.md` → `load-tools`

Keyed by **basename, with nesting flattened**: `commands/git/commit-msg.md`
becomes `/commit-msg`, not `/git:commit-msg`. The category directories are for
human navigation only — **basenames must be unique across the whole tree** or
one silently shadows the other.

### `agents/<name>.md` → `load-tools`

Flat, same loader, same flattening.

### `skills/<name>/SKILL.md` → `load-skills`

Keys `<name>` to the **directory** holding `SKILL.md`, so the whole skill
directory gets linked, not just the one file. Local skills are merged over a
pinned subset of `inputs.anthropic-skills`.

### `hooks/<name>.nu` → `mk-nu-script`

See below. `hooks/lib/*.nu` (`mod.nu`, `tools.nu`, `devenv.nu`) are shared
nushell modules, not hooks.

> **Loader values are paths, not file contents.** `programs.claude-code.{commands,agents}`
> is `attrsOf (either lines path)`, so handing it paths avoids one `readFile`
> per file at eval time. Keep it that way.

`output-styles/` and `rules/` hold only `.gitkeep` — scaffolding nothing reads
yet.

## Hooks

`claude.nix`'s `hook-scripts` attrset is the single source of truth: one row per
`hooks/<name>.nu`, giving what the script needs on `PATH` (`bins`) and which
events run it (`on.<Event> = { matcher?, timeout?, condition? }`). `condition`
becomes the hook's `if` field — permission-rule syntax the harness evaluates
_before_ spawning the command. The table is then inverted into Claude's
`event -> [hook]` shape.

**Adding a hook = add `hooks/<name>.nu` + one row.** Nothing else.

`mk-nu-script` builds each script with `writers.makeScriptWriter`, using
`nu-check --debug` as the build-time `check` — a parse error fails the
derivation with the diagnostic rather than at hook time. Scripts run on the
nixpkgs-pinned nushell with `--no-config-file`, independent of the interactive
shell's nu.

List only **external** commands in `bins`; nu built-ins already cover
`mkdir`/`rm`/`date`. Deliberate exception: `prune-comments` gets `claude` from
the session `PATH` rather than `bins`, to keep the unfree package out of the
wrapper closure.

`status-line` is built by the same table but is not a hook — it is wired to
`settings.statusLine`.

`mk-notifier` bakes one harness's identity into `hooks/notify.nu` as flags, so
callers pass just a message. Icons come from
`assets/<harness>{,-dark,-light}.png`, picked by system appearance at runtime;
`sender` is a macOS bundle id that makes Notification Center show that app's
icon.

## Skills materialization is two hops

Every skill first lands in `~/.agents/skills/<name>`. How it is linked onward
turns on one question: **does the harness write into its own skills directory?**

- **Writers get per-skill links** — one `mkOutOfStoreSymlink` per skill, so the
  directory itself stays real and writable. Claude (home-manager installs plugin
  skills into `~/.claude/skills/`) and Codex (built-ins in `.system/`,
  `$skill-installer` drops fetched skills alongside) both qualify. A whole-root
  link here would send their writes into the shared `.agents/skills` root and
  leak them into every other harness.
- **Readers get a whole-root link** — Antigravity, at
  `~/.gemini/antigravity-cli/skills`. Not `programs.antigravity-cli.skills`:
  that option copies its source into the store and so cannot point at `$HOME`.

Do not declare anything else under `.gemini/antigravity-cli/skills`: recent
home-manager renders `programs.antigravity-cli.commands` as skills inside that
same directory.

## Permissions

`_claude/permissions.nix` returns three profiles — `conservative`, `standard`,
`autonomous` — each `{ allow, ask, deny }` of Claude rule strings, built up by
layering (`allow.standard` extends `allow.conservative`). The matching
`conservative` / `standard` / `autonomous` sub-aspects in `claude.nix` select
one and set `defaultMode` to match.
