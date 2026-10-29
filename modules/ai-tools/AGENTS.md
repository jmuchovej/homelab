---
paths:
  - "modules/ai-tools/**"
---

# Authoring AI-tool config (`modules/ai-tools/`)

## Scope trap: this is `$HOME`, not this repo

These aspects build the **user's global agent config** — `~/.claude/`, `~/.gemini/`, `~/.agents/skills/` — through home-manager.
Nothing here configures agents _for the Rebellion repo_.

Repo-scoped agent instructions live in directory-level `AGENTS.md` files linked into `.agents/rules/` (this file is one of them).
If the guidance you are about to write is "when working in this repo, do X", it does not belong in this directory.

## Layout

One file per harness, each defining `rbn.programs._.ai-tools._.<harness>` with `_.cli` and `_.desktop` sub-aspects:

| File           | Aspect                         |
| -------------- | ------------------------------ |
| `claude.nix`   | `…_.claude` — Claude Code      |
| `gemini.nix`   | `…_.gemini` — Antigravity CLI  |
| `codex.nix`    | `…_.codex` — Codex CLI         |
| `ai-tools.nix` | `…_.mcp`, `…_.skills` (shared) |

`ai-tools.nix` also carries the `flake-file.inputs` declarations, the `flake.overlays.llm-agents` declaration beside its input (applied centrally by `modules/overlays.nix`), and the class-level `den.default.homeManager.imports` for `mcp-servers` — den does not honour `imports` on an aspect, so that module has to be imported at class level for its options to exist.

**`_`-prefixed paths are skipped by auto-discovery** and imported explicitly: `_lib.nix`, `_system-prompt.md`, `_claude/`.
This is the same role `.part.nix` plays elsewhere in the tree.

`_system-prompt.md` is one shared global system prompt: Claude takes it as `context`, Antigravity as `context.GEMINI`.

## The four content trees

All four are markdown walked by `import-tree` helpers in `_lib.nix`.
`initFilter` **must** be overridden in each — import-tree's default filter admits only `.nix`, and these trees are `.md`.

### `commands/<category>/<name>.md` → `load-tools`

Keyed by **basename, with nesting flattened**: `commands/git/commit-msg.md` becomes `/commit-msg`, not `/git:commit-msg`.
The category directories are for human navigation only — **basenames must be unique across the whole tree** or one silently shadows the other.

### `agents/<name>.md` → `load-tools`

Flat, same loader, same flattening.

### `skills/<name>/SKILL.md` → `load-skills`

Keys `<name>` to the **directory** holding `SKILL.md`, so the whole skill directory gets linked, not just the one file.
Local skills are merged over a pinned subset of `inputs.anthropic-skills`.

### `hooks/<name>.nu` → `mk-nu-script`

See below.
`hooks/lib/*.nu` (`mod.nu`, `tools.nu`, `devenv.nu`) are shared nushell modules, not hooks.

> **Loader values are paths, not file contents.**
> `programs.claude-code.{commands,agents}` is `attrsOf (either lines path)`, so handing it paths avoids one `readFile` per file at eval time.
> Keep it that way.

`output-styles/` and `rules/` hold only `.gitkeep` — scaffolding nothing reads yet.

## Hooks

`claude.nix`'s `hook-scripts` attrset is the single source of truth: one row per `hooks/<name>.nu`, giving what the script needs on `PATH` (`bins`) and which events run it (`on.<Event> = { matcher?, timeout?, condition? }`).
`condition` becomes the hook's `if` field — permission-rule syntax the harness evaluates _before_ spawning the command.
The table is then inverted into Claude's `event -> [hook]` shape.

**Adding a hook = add `hooks/<name>.nu` + one row.**
Nothing else.

`mk-nu-script` builds each script with `writers.makeScriptWriter`, using `nu-check --debug` as the build-time `check` — a parse error fails the derivation with the diagnostic rather than at hook time.
Scripts run on the nixpkgs-pinned nushell with `--no-config-file`, independent of the interactive shell's nu.

List only **external** commands in `bins`; nu built-ins already cover `mkdir`/`rm`/`date`.
Deliberate exception: `prune-comments` gets `claude` from the session `PATH` rather than `bins`, to keep the unfree package out of the wrapper closure.

`status-line` is built by the same table but is not a hook — it is wired to `settings.statusLine`.

### Worktrees

`worktree-create` puts every worktree the harness asks for at `~/Documents/dev/worktrees/_<harness name>/<repo>--<name>` (`harness worktrees-dir` in `hooks/lib/harness.nu`), never at the in-repo `.claude/worktrees/<name>` Claude proposes.
Outside the checkout is mandatory for colocated jj repos: a jj workspace has no `.git`, so inside a git checkout Claude's git discovery resolves to the main checkout and it refuses the path as an isolation worktree.
`<repo>` is the checkout's basename with no disambiguating hash: every repo has exactly one canonical tree (a fork is checked out once, with the fork as `origin` and the source as `upstream`).
`<name>` is the slug Claude keeps unique per worktree — user-given, generated, or `bridge-cse_<cloud session>`.
`session_id` would not do: every `isolation: worktree` subagent of one session shares it, and a fresh `--worktree <name>` launch must reopen the same directory.
`worktree-rename` reads the slug back from the segment after `--`.

`mk-notifier` bakes one harness's identity into `hooks/notify.nu` as flags, so callers pass just a message.
Icons come from `assets/<harness>{,-dark,-light}.png`, picked by system appearance at runtime; `sender` is a macOS bundle id that makes Notification Center show that app's icon.

## Paseo plugin (`paseo/`)

A pnpm workspace holding one Paseo plugin, `rbn-paseo-plugins` in `plugins/`, installed into the daemon by directory path (`paseo plugin install <absolute path to plugins/>`, then `paseo plugin reload rbn-paseo-plugins` after edits).
One plugin with separately registered parts, not one plugin per feature: `plugins/server/<feature>/<hook name>.ts` holds one hook handler each, `plugins/server/index.ts` re-exports them, and `index.server.ts` registers them.
Shared helpers live in `plugins/server/utils/` (`jj`); prefer importing them over re-declaring a local copy.
`jj` is a function with members, not a TS `namespace`: `jj(cwd)` returns a template tag that runs the full command, and `jj.log`, `jj.bookmark`, `jj.workspace` are the same tag with a fixed argv prefix (`command(...prefix)`), so a new subcommand is one line.
Every one of them has a `.try` that returns `null` instead of throwing (for example `` jj.bookmark.try(cwd)`rename a b` ``), and `jj.workspace.{is,name,root}` wrap the reads.
Members are attached with `defineProperty` (the `callable` helper), not `Object.assign`: a function's own `name` and `length` are read-only, so assigning a member called `name` onto a callable throws at plugin load, which tsc does not catch.
The tag follows execa's own contract because it is built on `parseCommandString`, which splits on spaces and knows no quoting: literal text splits, each `${}` stays one argument, an array spreads, so anything with spaces or quotes (a revset, a template) must be interpolated, never written inline.
Paths go through `pathe`, names through `scule`, processes through `execa` (with `reject: false` and `result.failed`), and filesystem checks and mutations through `fs-extra/esm` (`pathExists`, `copy`, `ensureDir`, `remove`, `readJson`), never `node:path`, hand-rolled case code, `child_process`, or a local `exists`.
`fs-extra/esm` exports only fs-extra's own methods, so a plain `readFile` stays on `node:fs/promises`.
execa's dependency chain logs one `fs.F_OK is deprecated`warning to the plugin's stderr at load; it is noise, not a fault.
The daemon compiles the TypeScript itself with esbuild and bundles runtime dependencies from`node_modules`, resolving pnpm's global virtual store as a linked dependency root; versions are pinned in the `catalog:`of`pnpm-workspace.yaml`.
Paseo supplies `@getpaseo/plugin` and zod at runtime; the SDK pins must track the installed daemon (`paseo --version`).
The `addHook`API with`workspace.create.before`/`workspace.create.after`/`workspace.archive.after`names is on paseo's main (#8081) but not in the released 0.14.0, whose SDK still has only`before`/`on`; the entry file carries a `STAGED`marker for the switch.
pnpm 12 refuses packages younger than its minimum release age and writes a`minimumReleaseAgeExclude`list into`pnpm-workspace.yaml`when told to proceed; expect to extend it on every bump.
No Node runtime is on PATH here (the nix`pnpm`is a standalone binary), so typecheck with bun from inside a package:`bun ./node_modules/typescript/bin/tsc --noEmit`.

### `jj-worktrees`

Paseo only knows `git worktree add`, and a git worktree carved from a colocated jj checkout has no `.jj`: agents in it cannot use jj, and `jj git init` there makes an unrelated repo that never links back to the default workspace.
The plugin intercepts `workspace.create` requests of kind `worktree`, runs `jj workspace add --colocate` itself, and returns the result as a `directory` source.
Paseo then classifies it as a `worktree` workspace (it has a main repo root) that paseo does not own.
A colocated secondary workspace is a real git worktree, so paseo's diff-against-base review works unchanged: HEAD sits at the parent of `@`, and `@`'s content shows as uncommitted changes.
Placement is `~/Documents/dev/worktrees/_paseo/<repo>/<slug>` (the Claude hook uses `_claude/<repo>--<name>`), and `devenv.local.nix` is copied over for the same reason it is there.
The slug is the request `title` when one is given (only the CLI's `--title` sends one; the app names workspaces after creation, from the first prompt), then the branch name, then paseo's generated slug, kebab-cased with scule's `splitByCase` (with a space separator added) and non-alphanumerics scrubbed so the result is a valid bookmark name.
The base is the picked `refName` when the app's full New-workspace screen or the CLI's `--base` sends one; otherwise `main@origin`, then `main`, then jj's default of the current `@-`.
A bookmark named after the slug is created on `@` at creation, so the first `jj commit` lands on it and `jj-hooks` (`advance-bookmarks`, see `programs/terminal/jujutsu.nix`) advances it from there; native paseo creates a git branch at the same point.
When paseo renames the workspace (first-prompt auto-naming or `paseo workspace rename`), the plugin renames the bookmark and the jj workspace to the slugified name, mirroring paseo's own branch rename; it learns about renames through `paseo.workspaces.subscribe`, which only fires while a `workspaces.list({ subscribe: {} })` is alive, so one is held for the plugin's lifetime.
`paseo.json` `worktree.setup` is re-implemented in `workspace.create.after.ts` (same file, same `bash -c`, same `PASEO_*` variables except `PASEO_WORKTREE_PORT`), because paseo only runs its own `runWorktreeSetupInBackground` from the git-worktree flow and the `workspace.setup.run` request starts setup only when it clears an `untrustedSource` block.
Output goes to `paseo plugin logs rbn-paseo-plugins`, not to the app's setup panel, and setup output that is not gitignored lands in `@`.
On `workspace.archived` for a path under that root, the plugin deletes the bookmark if it still points at `trunk()` or an empty change, then runs `jj workspace forget` and removes the directory, because paseo never deletes a directory it does not own.

Consequences that are not visible in the code:

- `paseo.json` `worktree.teardown` and `worktree.terminals` are paseo's: teardown still runs from the archive service, terminals are not started at all.
- Change-request and PR checkouts fall through to paseo's git path untouched.
- Agents must use jj inside the workspace.
  A `git commit` there makes jj reset `@` onto the new HEAD and leaves the old working-copy commit behind as a stray.
- The daemon is spawned by the desktop app with a GUI PATH, so `jj` is resolved from the nix profile paths listed in `server/utils/jj.ts`.
- The CLI sends only `cwd` while the app sends a `projectId`; the plugin resolves the project by root path so CLI-created workspaces nest under the checkout's project when one is registered.

## Skills materialization is two hops

Every skill first lands in `~/.agents/skills/<name>`.
How it is linked onward turns on one question: **does the harness write into its own skills directory?**

- **Writers get per-skill links** — one `mkOutOfStoreSymlink` per skill, so the directory itself stays real and writable.
  Claude (home-manager installs plugin skills into `~/.claude/skills/`) and Codex (built-ins in `.system/`, `$skill-installer` drops fetched skills alongside) both qualify.
  A whole-root link here would send their writes into the shared `.agents/skills` root and leak them into every other harness.
- **Readers get a whole-root link** — Antigravity, at `~/.gemini/antigravity-cli/skills`.
  Not `programs.antigravity-cli.skills`: that option copies its source into the store and so cannot point at `$HOME`.

Do not declare anything else under `.gemini/antigravity-cli/skills`: recent home-manager renders `programs.antigravity-cli.commands` as skills inside that same directory.

## Permissions

`_claude/permissions.nix` returns three profiles — `conservative`, `standard`, `autonomous` — each `{ allow, ask, deny }` of Claude rule strings, built up by layering (`allow.standard` extends `allow.conservative`).
The matching `conservative` / `standard` / `autonomous` sub-aspects in `claude.nix` select one and set `defaultMode` to match.
