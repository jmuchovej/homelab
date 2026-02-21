## Package discovery with platform filtering.
##
## Discovers packages from a directory, applies callPackage with self-reference,
## and filters out packages unsupported on the current platform.
{
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    fix
    isFunction
    isPath
    isString
    mapAttrsRecursive
    ;
  inherit (lib.meta) availableOn;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
in
{
  package = {
    ## Discover packages from a directory, callPackage them, and filter by platform.
    ## Returns an attrset of derivations supported on the current system.
    #@ { pkgs, paths } -> Attrs
    mk-packages =
      {
        pkgs,
        paths,
      }:
      let
        inherit (pkgs) callPackage;
        inherit (pkgs.stdenv) hostPlatform;

        package-fns = packagesFromDirectoryRecursive {
          directory = paths.packages;
          callPackage = file: _args: import file;
        };

        unsupported-platform =
          package-data:
          package-data ? platforms
          && (
            let
              platforms =
                if isFunction package-data.platforms then package-data.platforms lib else package-data.platforms;
            in
            !builtins.elem hostPlatform.system platforms
          );

        built-packages = fix (
          self:
          mapAttrsRecursive (
            _path: package-data:
            let
              package-fn = package-data.default or package-data;
            in
            if unsupported-platform package-data then
              null
            else if isFunction package-fn || isPath package-fn || isString package-fn then
              callPackage package-fn (self // { inherit inputs; })
            else
              package-data
          ) package-fns
        );
      in
      filterAttrs (
        _name: package:
        let
          eval = builtins.tryEval (
            package != null
            && (package ? type && package.type == "derivation")
            && (!(package ? meta.platforms) || availableOn hostPlatform package)
          );
        in
        eval.success && eval.value
      ) built-packages;
  };
}
