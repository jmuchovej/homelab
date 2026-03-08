# Nix Code Style

Universal Nix code formatting and patterns for rebellion.

## Quick Commands

- **Format code:** `nix fmt`
- **Fix style violations:** `/nix-refactor` command
- **Validate syntax:** Hooks run automatically on Edit/Write
- **Scaffold new module:** `/module-scaffold` - Follows these patterns
- **Update flake inputs:** `/flake-update` command

## Imports

**Never use `with lib;`** - it obscures function origins and causes namespace
pollution.

```nix
# Good: Explicit imports
let
  inherit (lib) mkIf mkEnableOption types;
  inherit (lib.strings) concatStringsSep;
in

# Also good: Inline lib prefix
config = lib.mkIf cfg.enable { };

# Bad: with statement
with lib;
```

## Naming Conventions

- **Variables/options:** kebab-case (`sign-by-default`, `permissions-profile`,
  `mcp-servers`)
- **Files/directories:** kebab-case (`my-module/`, `default.nix`,
  `my-program.nix`)
- **Lib functions:** kebab-case (`mk-module`, `mk-enable`, `mk-bool`,
  `get-file`)
- **Options:** Always under `rebellion.*` namespace
  - Pattern: `rebellion.{category}.{subcategory}.{name}`
  - Example: `rebellion.programs.terminal.shells.zsh.enable`

## Conditionals

**Prefer `lib.mkIf` over `if then else`** for module configs:

```nix
# Good: mkIf for module config
config = mkIf cfg.enable {
  programs.git.enable = true;
};

# Acceptable: if/then for values
value = if condition then "yes" else "no";

# Good: mkDefault for overridable defaults
programs.git.userName = mkDefault "user";

# Use sparingly: mkForce to override
programs.git.userName = mkForce "override";
```

## Module Structure Pattern

**Always use `lib.rebellion.mk-module`** — it handles option nesting, `enable`
creation, `cfg` extraction, and `mkIf` wrapping automatically.

### Minimal module (no custom options)

```nix
{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "category.program";
  config = { lib, pkgs, ... }: {
    programs.example.enable = true;
  };
}
```

### Module with custom options

```nix
{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "category.program";

  options = { lib, ... }:
    let
      inherit (lib.rebellion.options) mk;
      inherit (lib.types) str bool;
    in
    {
      extra-config = mk str "" "Extra configuration lines.";
      sign-commits = mk bool true "Whether to sign commits.";
    };

  config = { cfg, lib, pkgs, ... }: {
    # cfg = config.rebellion.category.program (auto-extracted)
    # cfg.enable is auto-created by mk-module
    # cfg.extra-config, cfg.sign-commits from your options above
    programs.example = {
      enable = true;
      extraConfig = cfg.extra-config;
    };
  };
}
```

### mk-module parameters

| Parameter | Purpose |
|---|---|
| `name` | Option path under `rebellion.*`, auto-creates `.enable` |
| `namespace` | Like `name` but **no** `.enable` — always active |
| `options` | Custom options (attrset or function receiving module-args) |
| `config` | Module config (attrset or function receiving module-args + `cfg`) |
| `conditions` | Extra guard beyond `cfg.enable` (function or bool) |
| `imports` | Sub-imports (can be functions receiving eval-args) |
| `always-active` | If true, `enable` defaults to `true` |

### `name` vs `namespace`

- **`name`**: Creates `rebellion.{name}.enable` option (default `false`).
  Config only applies when enabled.
- **`namespace`**: No enable option. Config always applies.
  Use for aggregation modules (e.g., collecting homebrew casks).

### How `@args` flows through mk-module

```nix
{ lib, pkgs, ... }@args:
#  ↑ top-level destructuring    ↑ captures ALL module-args (config, lib, pkgs, ...)
lib.rebellion.mk-module args {
  # mk-module creates eval-args = args // { cfg }
  # and passes eval-args to options, config, and imports functions

  config = { cfg, lib, pkgs, ... }: {
    #         ↑ eval-args destructuring — must re-destructure here
    # pkgs, config, lib, etc. come from eval-args, NOT from the outer scope
    home.packages = [ pkgs.ripgrep ];
  };
}
```

**Why `pkgs` must appear in the config function's destructuring:**
`mk-module` calls the config function with `eval-args`, not with the outer
scope. Even though `@args` captures `pkgs`, the inner function has its own
scope — you must destructure `pkgs` (and anything else you need) from the
args the inner function receives.

The top-level destructuring (`{ lib, pkgs, ... }@args`) serves two purposes:
1. Makes args available **outside** `mk-module` (rarely needed)
2. Documents which module-args this file depends on

### Key points

- Never write manual `options.rebellion.* = { enable = mkEnableOption ... }`
  boilerplate — `mk-module` handles it
- The `config` function receives `cfg` automatically — no need for manual
  `cfg = config.rebellion.category.program`
- Use `osConfig ? {}` in module-args when Home Manager modules need system config
- Option helpers: `mk type default description`, `mk-bool`, `mk-enable`

## Functions

```nix
# Pure functions only - same inputs = same outputs
my-function = arg1: arg2: arg1 + arg2;

# Explicit parameter destructuring
my-function = { name, value, extra-args ? {} }:
  # implementation

# Use `inherit` for clarity
let
  inherit (inputs.nixpkgs) lib;
in
```

## Common Antipatterns

**Avoid `with` statements:**

```nix
# Bad: obscures origins
with lib; with pkgs;

# Good: explicit imports when used multiple times
let
  inherit (lib) mkIf mkOption mkEnableOption;
in

# Also good: inline lib. prefix when used once
config = lib.mkIf cfg.enable { };
```

**Other antipatterns:**

```nix
# Bad: if/then for module config
config = if cfg.enable then { ... } else {};

# Good: use mkIf instead
config = lib.mkIf cfg.enable { ... };

# Bad: impure functions
readFile /etc/config  # evaluation-time I/O
```

## File Organization

### Auto-discovery rules

All `*.nix` files are auto-discovered and imported **except**:
- `*.part.nix` — skipped by auto-discovery, must be imported explicitly
- `default.nix` — skipped by auto-discovery

**Never create `default.nix` as a directory index.** Auto-discovery makes it
unnecessary. Each `.nix` file should be a standalone `mk-module`.

### `.part.nix` files — non-module fragments

Use the `.part.nix` suffix for files that are **not** standalone modules.
These are imported explicitly by a parent module, not auto-collected.

Two common patterns:

**1. As mk-module imports** — receive `eval-args` (including `cfg`), return
NixOS/HM config:

```
system/networking/
├── networking.nix           # mk-module, imports .part.nix via `imports = [...]`
├── dnsmasq.part.nix         # receives { cfg, config, lib, ... }, returns config
├── networkmanager.part.nix
└── resolved.part.nix
```

```nix
# dnsmasq.part.nix — receives eval-args from mk-module
{ cfg, config, lib, ... }:
mkIf (cfg.dns == "dnsmasq") {
  services.dnsmasq.enable = true;
}
```

**2. As data fragments** — receive explicit args, return data to be merged:

```
editor/
├── zed.nix                  # mk-module, imports .part.nix via import-dir
└── zed/
    ├── base.part.nix        # receives { lib, ... }, returns settings fragment
    ├── fonts.part.nix
    ├── vim.part.nix
    └── languages-lsps/
        ├── json.part.nix
        └── yaml.part.nix
```

```nix
# base.part.nix — plain function returning data
{ lib, ... }: {
  settings = lib.mkMerge [
    { autosave = "on_focus_change"; }
    { auto_update = false; }
  ];
}
```

### When to split into `.part.nix` files

- Module exceeds ~200 lines
- Logically distinct sub-configurations (DNS backends, editor panels)
- Configuration variants selected by an option (e.g., `cfg.dns == "dnsmasq"`)

## Formatting

- **Indentation:** 2 spaces (enforced by `nix fmt`)
- **Line length:** Aim for <100 chars, not strict
- **List items:** One per line for readability
- **Attribute sets:** Break across lines when >3 attributes

```nix
# Good: readable list
home.packages = with pkgs; [
  git
  vim
  ripgrep
];

# Good: multiline attrset
programs.git = {
  enable = true;
  userName = "user";
  userEmail = "user@example.com";
};
```

**Note:** 8 Nix skills apply automatically when needed (writing-nix,
validating-nix, managing-flakes, and others).
