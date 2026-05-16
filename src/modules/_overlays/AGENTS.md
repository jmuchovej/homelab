# `/overlays/` (Custom Overlays)

These are custom overlays for the `rebellion` configuration. Refer to
[`/_packages/AGENTS.md`](./_packages/AGENTS.md) for more details on how to decide
between using packages or overlays.

## Library Structure

```shell
overlays/
└── {overlay-name}.overlay.nix        # Package derivation
```

Packages are auto-discovered by `flake-parts` and exposed via
`pkgs.rebellion.{package-name}`.

## When to create packages

**Create a package in `/packages/` when:**

- Completely custom derivation used in your configuration (e.g., wallpapers,
  scripts, helpers, etc.).
- Complex derivation that's nearly impossible to write as an overlay.
- There's a permanent, custom, package that's specific to the `rebellion`.

**Instead, use an overlay (in `/overlays/`) when:**

- Overriding the existing `nixpkgs` package.
- Patching an upstream package.
- Changing build flags on an existing package.

## Building and Testing

```bash
# Build package
nix build .#my-tool

# Run without building system
nix run .#my-tool

# Test the result
./result/bin/my-tool

# Check what's in the package
ls -la result/
```

## Using in Configuration

Packages are available as `pkgs.rebellion.{package-name}`:

```nix
# In any module
home.packages = [ pkgs.rebellion.my-tool ];

# Or directly
programs.some-program.package = pkgs.rebellion.my-tool;
```
