---
paths:
  - "**/*.nix"
---

# Nix style

How Nix is written in this repo. den-specific structure is `den-style.md`;
this is the language-level layer under it.

## Formatting

`nix fmt` (treefmt) owns layout. Never hand-format and never argue with it —
hooks reject unformatted files.

## Scope and names

- **`with` never at file or module scope.** `with pkgs; [ … ]` on a single
  list literal is fine; `with lib;` is not, anywhere.
- One or two `lib` names: inline `lib.mkIf`. Three or more:
  `inherit (lib) mkIf mkMerge optionalAttrs;` in a `let`.
- **Identifiers you own are kebab-case** (`hook-scripts`, `mk-hook`,
  `just-lsp`, `extended-lib`); so are files and directories. Names that belong
  to upstream (`sopsFile`, `allowedDomains`, `userSettings`) keep upstream's
  casing — never rename to match.
- Constructors are `mk-*`, predicates `is-*`. A trailing `'` marks a
  convenience variant with a defaulted argument (`get-secret'`).
- Destructure only the args a function uses, always with `...`.

## Conditionals and merging

- Config blocks: `lib.mkIf` / `lib.mkMerge`. Pieces of a value:
  `lib.optional`, `optionals`, `optionalAttrs`, `optionalString`.
- Plain values: `if … then … else` is fine. Do not wrap a value in `mkIf`.
- Flat attrsets: `//`. Module config: `mkMerge`. Nested data:
  `lib.rbn.merge-deep`.
- `mkDefault` for things a host may override. `mkForce` is a last resort and
  carries a comment naming what it overrides and why.

## Files and discovery

- `import-tree` loads every `*.nix` under a module tree. Anything that must
  not load on its own — helpers, fragments, asset dirs, per-host hardware —
  gets a **`_` prefix** and is imported explicitly by its owner. `.part.nix`
  is the legacy spelling of the same idea; don't add new ones.
- One aspect (or one concern) per file. Split by `_.<sub-aspect>` or
  `provides`, never by a `default.nix` index.

## Flake inputs

Declare an input **in the file that consumes it** with
`flake-file.inputs.<name>.url = …;`. `flake.nix` is generated (`just regen`) —
never edit it by hand, never add inputs there.

## Purity

No evaluation-time I/O: no `readFile` on absolute paths, no unpinned
`builtins.fetch*`. Helpers under `lib.rbn` are pure functions.

## Comments

Say why, not what. Before committing, apply the comment sweep in the root
`AGENTS.md`: keep only comments load-bearing at that line; lift the rest into
the governing `AGENTS.md`.
