# Custom Library Functions

Reusable Nix functions extending `nixpkgs.lib` for `rebellion`-specific patterns.

## Library Structure

```shell
$ tree lib
  lib
├──   system            	# System/host builders
│   ├──   common.nix			# Shared functions between homes, macos, & nixos
│   ├──   mk-homes.nix		# Builder for home-manager configurations
│   ├──   mk-macos.nix   # Builder for macOS configurations
│   └──   mk-nixos.nix   # Builder for NixOS configurations
├──   AGENTS.md
├──   default.nix
├──   file.nix       		# File system operations
└──   module.nix       	# Module creation utilities
```

## Core Principles

### 1. Pure Functions

All lib functions must be pure:

- No side effects
- Same inputs always produce same outputs
- No file I/O during evaluation (except via builtins)

### 2. Explicit Function Parameters

Lib functions accept `inputs` parameter and extract needed dependencies:

```nix
{ inputs }:
let
  # Extract only what this lib module needs
  inherit (inputs.nixpkgs.lib) mkOption types mapAttrs;
in
{
  # Function definitions using the inherited values
  my-function = arg: /* ... */;
}
```

This keeps lib functions self-contained and makes dependencies explicit.

### 3. Namespaced Exports

Export via `flake.lib.{category}`:

```nix
# lib/default.nix
{
  flake.lib = {
      # keep-sorted start block=yes newline_separated=yes
      file = import ./file { inherit inputs; self = ../.; };
      module = import ./module { inherit inputs; };
      overlay = import ./overlay.nix { inherit inputs; };
      system = {
        # System configuration builders
        home = import ./system/mk-home.nix { inherit inputs; };
        macos = import ./system/mk-macos.nix { inherit inputs; };
        nixos = import ./system/mk-nixos.nix { inherit inputs; };

        # Common utilities used by system builders
        common = import ./system/common.nix { inherit inputs; };
      };
    };
}
```

## Library Categories

- **file**: File operations (`get-file`, `import-dir`, `scan-dir`, etc.)
- **module**: Module helpers (`enabled`, `mkopt`, `mkopt-bool`, `mk-module`)
- **system**: System builders (`mk-nixos`, `mk-macos`, `mk-homes`)
- **overlay**: Overlay creation helpers

Function details are documented in the source code.

## Creating New Library Functions

### 1. Choose Category

Determine which category fits your function:

- File operations → `file.nix`
- Module utilities → `module.nix`
- System builders → `system/`
- New category → Create top-level file. **IF** it's sensible to split into multiple files, mirror the setup of `system/`

### 2. Write Pure Function

```nix
{ inputs }:
let
  inherit (inputs.nixpkgs.lib) mapAttrs filterAttrs;
in
{
  # Document the function
  # @param arg1 Description of arg1
  # @param arg2 Description of arg2
  # @return Description of return value
  # @example myFunction "a" "b" => "ab"
  my-function = arg1: arg2:
    # Pure implementation
    # No side effects
    # Deterministic output
    arg1 + arg2;
}
```

### 3. Document Function

Add clear documentation with:

- Brief description of what function does
- Parameter descriptions
- Return value description
- Usage example

### 4. Export in default.nix

```nix
# lib/default.nix
{
  flake.lib = {
    # Existing categories...
    my-category = import ./my-category { inherit inputs; };
  };
}
```

### 5. Test Function

```bash
# Test in nix repl
nix repl
> :lf .
> lib.rebellion.my-category.my-function "a" "b"
"ab"
```

## When to Add Library Functions

**Add to lib when:**

- Function is reused across multiple modules
- Logic is complex and benefits from abstraction
- Pattern is common throughout codebase
- Function has no side effects

**Don't add to lib when:**

- Used only once
- Module-specific logic
- Requires side effects
- Better expressed inline

## Common Patterns

### Option Creation

```nix
mkopt = type: default: description:
  lib.mkOption {
    inherit type default description;
  };
```

### Safe Import

```nix
safe-import = path: default:
  if builtins.pathExists path
  then import path
  else default;
```

### Directory Import

```nix
import-dir = path: args:
  let
    entries = builtins.readDir path;
    nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) entries;
  in
  lib.mapAttrs (name: _: import (path + "/${name}") args) nixFiles;
```

## Testing

```bash
# Test in nix repl
nix repl
> :lf .
> lib.rebellion.file.get-file "modules"
/nix/store/.../modules

# Test via build
nix eval .#lib.rebellion.file.scan-dir ./lib
[ "system" ]
```
