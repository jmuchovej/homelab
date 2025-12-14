# `/packages/` (Custom Packages)

These are custom packages for the `rebellion` configuration.

## Library Structure

```shell
$ tree packages/
 packages/
├──   {package-name}.nix
└──   {package-name}
    └──   package.nix
```

Packages are auto-discovered by `flake-parts` and exposed via `pkgs.rebellion.{package-name}`.

Since we discover packages via `packagesFromDirectoryRecursive`, this means the directory structure can be flat or must contain a `{package-name}/package.nix` structure. Having `{package-name}.nix` is preferred because it increases specificity at the file level.

**NOTE:** `{package-name}` may be a nested directory, which would create a namespaced package. e.g. suppose there are fonts, like `monolisa` and `roboto`, with `/packages/fonts/monolisa.nix` and `packages/fonts/roboto.nix` respectively. When used, they would be exposed as `pkgs.rebellion.fonts.monolisa` and `pkgs.rebellion.fonts.roboto`. This is useful for organizing related packages and ensuring they are easily accessible within the configuration.

## When to create packages

**Create a package in `/packages/` when:**

- Completely custom derivation used in your configuration
  (e.g., wallpapers, scripts, helpers, etc.).
- Complex derivation that's nearly impossible to write as
  an overlay.
- There's a permanent, custom, package that's specific to
  the `rebellion`.

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
