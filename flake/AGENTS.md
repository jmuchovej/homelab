# `/flake`

This directory contains a flake definition that mimics many original behaviors of `snowfall/lib`, but with customized behaviors. (Much of the work here was inspired, or derived, from `snowfall/lib` and `khaneliman/khanelinix`'s migration to `flake-parts`.)

This flake also extends the standard `nixpkgs.lib` via the `/lib/` directory. These are custom library functions and utilities to help with system configuration and package management.

## Library Structure

```shell
$ tree flake
 flake
├──   default.nix
├──   homes.nix
├──   modules.nix
├──   overlays.nix
├──   packages.nix
└──   systems.nix
```

1. `default.nix` organizes exports, as usual
2. `modules.nix` splitting things like flake overlays and modules across multiple files is annoying, so this allows for centralizing them in `flake.nix`.
3. `overlays.nix` discovers (to provide) local overlays
4. `packages.nix` discovers (to provide) local packages
5. `systems.nix` discovers `/systems/` and configures macOS and NixOS
6. `homes.nix` discovers `/homes/` and configures them per-system

## Core Principles
