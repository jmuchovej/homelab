---
paths:
  - "src/lib/**"
---

# Library Functions

Custom reusable Nix functions extending nixpkgs.lib.

## When to Create a Lib Function

**Create in src/lib/ when:**

- Function is reused across multiple modules (3+ uses)
- Logic is complex and benefits from abstraction
- Pattern is common throughout codebase
- Function is pure (no side effects)

**Don't create lib function when:**

- Used only once or twice
- Simple one-liner
- Module-specific logic
- Better expressed inline

## Categories

All functions use kebab-case and live under `lib.rebellion.*`.

### base64

Encoding/decoding utilities for secrets and data.

### fs (file system)

- `get-file` - Absolute path from repo root
- `import-dir` - Import all .nix files in directory
- `scan-dir` - List directory contents

### options

- `enabled` / `disabled` - Shorthand for `{ enable = true/false; }`
- `mk type default description` - Create option (curried 3-arg)
- `mk' type default` - Create option without description
- `mk-bool default description` - Boolean option helper
- `mk-enable name default` - Creates `{ enable = mk-bool ... }`
- `mk-enable' name` - Like `mk-enable` but defaults to `false`
- `mk-package` / `mk-package'` - Package option helpers

### modules

- `mk-module args spec` - Primary module builder (see nix-style.md)
- `mk-desktop-module args spec` - Like `mk-module` but adds
  `rebellion.desktop.enable` as an extra guard condition
- `get-shared path` - Load a module from `modules/shared/`

### theme

- `get-theme` - Get theme configuration
- `mk-color-scheme` - Create color scheme
- `apply-theme` - Apply theme to program

## Principles

- **Pure functions only** - no side effects, no I/O during evaluation
- **Same inputs → same outputs** - deterministic
- **Explicit parameters** -
  `{ inputs }: let inherit (inputs.nixpkgs.lib) ...; in { ... }`
- **Export via category** - `flake.lib.{category}.{function}`

## Usage

```nix
# In modules — option helpers
{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.git";
  options = { lib, ... }:
    let
      inherit (lib.rebellion.options) mk;
    in
    {
      signing-key = mk lib.types.str "" "SSH key path for signing.";
    };
  config = { cfg, ... }: {
    programs.git.extraConfig.user.signingkey = cfg.signing-key;
  };
}

# In other modules — enabled/disabled helpers
rebellion.programs.git = enabled;
sops.defaultSopsFile = lib.rebellion.fs.get-file "secrets/default.yaml";
```

## Creating New Functions

```nix
# src/lib/my-category.nix
{ lib, rebellion-lib, inputs }:
let
  inherit (lib) mapAttrs;
in
{
  my-category = {
    my-function = arg1: arg2: arg1 + arg2;
  };
}
```

Then wire into `src/lib/default.nix`.

## Testing

```bash
nix repl
> :lf .
> lib.rebellion.options.enabled
{ enable = true; }
```
