{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    isFunction
    genAttrs
    attrValues
    composeManyExtensions
    ;
  inherit (builtins) pathExists;
  inherit (self.lib.file) get-nix-files safe-import;

  overlays-path = ../overlays;
  dynamic-overlays-set =
    if !(pathExists overlays-path) then
      { }
    else
      let
        overlay-dirs = get-nix-files overlays-path;
      in
      genAttrs overlay-dirs (
        name:
        let
          overlay-path = overlays-path + "/${name}";
          overlay-fn = import overlay-path;
        in
        if isFunction overlay-fn then
          overlay-fn {
            inherit inputs;
          }
        else
          overlay-fn
      );

  rebellion-packages-overlay =
    final: prev:
    let
      directory = ../packages;

      # Get the callPackage function for a given directory path
      # Looks for default.nix files that export { callPackage = ...; }
      get-call-package-for-path =
        dirpath:
        let
          # safe-import will check for default.nix automatically
          config = safe-import dirpath { };
        in
        config.callPackage or null;

      # Helper to recursively callPackage on nested attribute sets
      # Discovers and uses callPackage overrides from default.nix files
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
            # Only check for callPackage overrides if value is an attr set (indicating a subdirectory)
            dirpath = basepath + "/${name}";
            disc-call-pkg-fn =
              if prev.lib.isAttrs value && !prev.lib.isDerivation value then
                get-call-package-for-path dirpath
              else
                null;
            # Use directory's callPackage if specified, otherwise inherit from parent
            call-pkg-fn = if disc-call-pkg-fn != null then disc-call-pkg-fn final else curr-call-pkg-fn;
          in
          if prev.lib.isDerivation value then
            value
          else if prev.lib.isFunction value then
            call-pkg-fn value (self // { inherit inputs; })
          else if prev.lib.isAttrs value then
            call-package-rec {
              inherit self;
              basepath = dirpath;
              curr-call-pkg-fn = call-pkg-fn;
              attrs = value;
            }
          else
            value
        ) attrs;

      # Get the root callPackage (from packages/default.nix if it exists)
      root-call-pkg-fn =
        let
          fn = get-call-package-for-path directory;
        in
        if fn != null then fn final else final.callPackage;

      package-fns = prev.lib.filesystem.packagesFromDirectoryRecursive {
        inherit directory;
        callPackage = file: _args: import file;
      };
    in
    {
      rebellion = prev.lib.fix (
        self:
        call-package-rec {
          inherit self;
          basepath = directory;
          curr-call-pkg-fn = root-call-pkg-fn;
          attrs = package-fns;
        }
      );
    };

  all-overlays = (attrValues dynamic-overlays-set) ++ [ rebellion-packages-overlay ];
in
{
  flake = {
    overlays = dynamic-overlays-set // {
      default = rebellion-packages-overlay;
      rebellion = rebellion-packages-overlay;
    };

    perSystem =
      { config, pkgs, ... }:
      {
        pkgs = pkgs.extend (composeManyExtensions all-overlays);

        packages = config.pkgs.rebellion;
      };
  };
}
