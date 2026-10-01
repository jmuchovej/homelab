---
paths:
  - "modules/_lib/**"
---

# _lib/ — `lib.rbn` helpers

`_`-prefixed: skipped by flake-level auto-discovery; `defaults.nix` imports
this directory explicitly. Each file is a function
`{ lib, inputs }: { _rbn-lib = { … }; }` — contributions merge into `lib.rbn`
by **extending nixpkgs.lib** (`lib.extend`), because a lib extension
propagates everywhere `nixosSystem`'s `lib` reaches — including den aspect
inner functions — which specialArgs / `_module.args` cannot do. That's the
whole reason this mechanism exists; don't convert it to specialArgs.

Files by concern:

| File        | Exports                                                      |
| ----------- | ------------------------------------------------------------ |
| `lsp.nix`   | `mk-lsp`                                                     |
| `macos.nix` | `macos.{keycode,symbolic-hotkey}` (the one nested namespace) |
| `shell.nix` | `argv`                                                       |
| `sops.nix`  | `get-file`, `get-secrets`, `get-secret`, `get-secret'`       |
| `yaml.nix`  | `from-yaml`, `render-yaml`                                   |

Helpers must be pure functions. Add a new concern as a new file — it is
auto-collected; name helpers kebab-case.

## `argv` — why it exists

`shell.nix` exports `argv = lib.splitString " "`. Use it for a value that is
**one command line** — a program's positional args and flags, where splitting
on whitespace is semantically identical to the list literal:

```nix
clone = argv "util exec -- ${getExe jj-clone}";   # not [ "util" "exec" … ]
```

nixfmt expands every list literal with more than one element onto its own
line, unconditionally — that rule is RFC 166 style, hardcoded, and has no
width or complexity knob (`nixfmt` offers only `--width`/`--indent`). A
four-token command therefore costs six lines. nixfmt leaves a list-valued
_expression_ alone, so `argv` buys back the one-liner without switching
formatters. (The author-preserving alternatives, alejandra and nixpkgs-fmt,
would mean reflowing the whole tree and diverging from nixpkgs style.)

Boundaries — `argv` is **not** a general list-compaction trick:

- Only for argv. A list of kernel modules, mount options, font families,
  groups or DNS servers stays a literal; those read better one-per-line and
  are not a command line.
- Not for long flag sets either (`ripgrep.arguments`, `fzf.defaultOptions`) —
  one flag per line is the point there.
- Never when an element can contain a space. Store paths cannot; arbitrary
  interpolated user paths can, so check before interpolating one.
- It hides that the value is a list, so grepping for an element as a list
  member stops working. That's the trade; it is worth it only for genuine
  command lines.

`lib.splitStringBy` is **not** a substitute: it takes a predicate plus a
`keepSplit` flag, so `lib.splitStringBy " " str` silently evaluates to a
lambda rather than a list.
