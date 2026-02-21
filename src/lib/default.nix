## Bootstrap for lib.rebellion — Two-Phase Architecture
##
## Phase 1: Build `rebellion-lib` via fixed-point recursion (`fix`).
##   All modules receive { lib, rebellion-lib, inputs } where:
##     - `lib` = raw `inputs.nixpkgs.lib` (standard functions)
##     - `rebellion-lib` = `self` from the fixpoint (sibling cross-refs)
##     - `inputs` = flake inputs
##
## Phase 2: Construct the final extended `lib` outside `fix`.
##   This adds `lib.rebellion.*` aliases and top-level convenience re-exports.
##   `mk-flake` is curried with the final `lib` so that NixOS/HM modules
##   receive the fully-extended lib via `_module.args.lib`.
{ inputs }:
let
  nixpkgs-lib = inputs.nixpkgs.lib;

  inherit (nixpkgs-lib)
    fix
    hasSuffix
    isFunction
    recursiveUpdate
    ;
  inherit (builtins)
    readDir
    attrNames
    filter
    foldl'
    ;

  src = ./.;

  # Filter for discoverable *.nix files (excludes default.nix and *.part.nix)
  discover-nix-files =
    dir:
    let
      entries = readDir dir;
    in
    filter (
      name:
      entries.${name} == "regular"
      && hasSuffix ".nix" name
      && name != "default.nix"
      && !(hasSuffix ".part.nix" name)
    ) (attrNames entries);

  # Discover public library modules from src/lib/
  module-names = discover-nix-files src;

  # Discover internal builder modules from src/lib/lib/
  internal-lib = src + "/lib";
  internal-module-names = discover-nix-files internal-lib;

  # Recursively merge a list of attribute sets (later wins at each level).
  merge-deep = foldl' recursiveUpdate { };

  # ---------------------------------------------------------------------------
  # Phase 1: rebellion-lib = fix(self => ...)
  # ---------------------------------------------------------------------------
  rebellion-lib = fix (
    self:
    let
      call-module =
        dir: name:
        let
          imported = import "${dir}/${name}";
        in
        if isFunction imported then
          imported {
            lib = nixpkgs-lib;
            rebellion-lib = self;
            inherit inputs;
          }
        else
          imported;

      modules = map (call-module src) module-names;
      internal-modules = map (call-module internal-lib) internal-module-names;
    in
    merge-deep (modules ++ internal-modules)
  );

  # ---------------------------------------------------------------------------
  # Phase 2: final extended lib
  # ---------------------------------------------------------------------------
  lib = nixpkgs-lib.extend (
    _final: _prev: {
      rebellion =
        rebellion-lib
        # Flatten top-level module helpers into rebellion namespace
        // rebellion-lib.modules or { }
        // rebellion-lib.options or { }
        // rebellion-lib.fs or { }
        // rebellion-lib.attrs or { }
        // {
          # Backward-compat alias: lib.rebellion.file -> lib.rebellion.fs
          file = rebellion-lib.fs;

          # mk-flake curried with final lib — NixOS/HM modules get the extended lib
          mk-flake = rebellion-lib.mk-flake lib;
        };

      # Top-level lib.* re-exports for convenience in modules
      inherit (rebellion-lib.fs)
        walk-files
        get-files
        load-file
        get-file
        get-nix-files
        scan-dir
        import-files
        import-dir
        import-dir-plain
        import-subdirs
        discover-modules
        ;

      inherit (rebellion-lib.attrs or { })
        merge-attrs
        merge-shallow
        mk-default
        mk-force
        ;

      inherit (rebellion-lib.modules or { })
        mk-module
        mk-desktop-module
        ;

      inherit (rebellion-lib.options or { })
        mk
        mk'
        mk-bool
        mk-bool'
        mk-enable
        mk-package
        mk-package'
        enabled
        disabled
        ;

      # home-manager lib functions
      inherit (inputs.home-manager.lib) hm;
    }
  );
in
lib
