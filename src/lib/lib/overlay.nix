## Overlay discovery & building.
##
## Discovers overlays from `overlays/`, builds the packages overlay
## (pkgs.rebellion.*), and composes them all together.
{
  lib,
  rebellion-lib,
  inputs,
}:
let
  inherit (lib)
    attrValues
    fix
    genAttrs
    isAttrs
    isDerivation
    isFunction
    removeSuffix
    ;
  inherit (builtins) pathExists unsafeDiscardStringContext;

  inherit (rebellion-lib) fs;
in
{
  overlay = rec {
    ## Discover overlay files from an overlays directory.
    ## Each file is imported; if it's a function, it receives { inputs }.
    ## Returns an attrset: { overlay-name = <overlay-fn>; ... }
    #@ Path -> Attrs
    discover-overlays =
      overlay-path:
      if !(pathExists overlay-path) then
        { }
      else
        let
          overlay-files = fs.get-nix-files overlay-path;
          names = map (f: removeSuffix ".nix" (unsafeDiscardStringContext (baseNameOf f))) overlay-files;
        in
        genAttrs names (
          name:
          let
            overlay-fn = import (overlay-path + "/${name}.nix");
          in
          if isFunction overlay-fn then overlay-fn { inherit inputs; } else overlay-fn
        );

    ## Build the packages overlay that creates `pkgs.rebellion.*`.
    ## Discovers packages from a directory and uses callPackage with
    ## recursive self-reference and optional per-directory callPackage overrides.
    #@ Path -> Overlay
    mk-packages-overlay =
      packages-path: final: prev:
      let
        get-call-package-for-path =
          dirpath:
          let
            config = fs.safe-import dirpath { };
          in
          config.callPackage or null;

        call-package-rec =
          {
            self,
            basepath,
            curr-call-pkg-fn,
            attrs,
          }:
          prev.lib.mapAttrs (
            name: value:
            let
              dirpath = basepath + "/${name}";
              disc-call-pkg-fn =
                if isAttrs value && !isDerivation value then get-call-package-for-path dirpath else null;
              call-pkg-fn = if disc-call-pkg-fn != null then disc-call-pkg-fn final else curr-call-pkg-fn;
            in
            if isDerivation value then
              value
            else if isFunction value then
              call-pkg-fn value (self // { inherit inputs; })
            else if isAttrs value then
              call-package-rec {
                inherit self;
                basepath = dirpath;
                curr-call-pkg-fn = call-pkg-fn;
                attrs = value;
              }
            else
              value
          ) attrs;

        root-call-pkg-fn =
          let
            fn = get-call-package-for-path packages-path;
          in
          if fn != null then fn final else final.callPackage;

        package-fns = prev.lib.filesystem.packagesFromDirectoryRecursive {
          directory = packages-path;
          callPackage = file: _args: import file;
        };
      in
      {
        rebellion = fix (
          self:
          call-package-rec {
            inherit self;
            basepath = packages-path;
            curr-call-pkg-fn = root-call-pkg-fn;
            attrs = package-fns;
          }
        );
      };

    ## Build the complete overlay set for the flake.
    ## Returns { overlays, all-overlays } where:
    ##   overlays: Named attrset for flake.overlays output (dynamic + default/rebellion)
    ##   all-overlays: Flat list of all overlays for nixpkgs config
    #@ { paths, external-overlays? } -> Attrs
    mk-overlays =
      {
        paths,
        overlays ? [ ],
      }:
      let
        dynamic = discover-overlays paths.overlays;
        packages = mk-packages-overlay paths.packages;
        all = (attrValues dynamic) ++ [ packages ] ++ overlays;
      in
      {
        overlays = dynamic // {
          default = packages;
          rebellion = packages;
        };
        all-overlays = all;
      };
  };
}
