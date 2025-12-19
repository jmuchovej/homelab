{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (lib)
        fix
        mapAttrsRecursive
        filterAttrs
        isFunction
        isPath
        isString
        ;
      inherit (lib.meta) availableOn;
      inherit (lib.filesystem) packagesFromDirectoryRecursive;
      inherit (pkgs) callPackage;
      inherit (pkgs.stdenv) hostPlatform;

      package-fns = packagesFromDirectoryRecursive {
        directory = ../packages;
        callPackage = file: _args: import file;
      };

      built-packages = fix (
        self:
        mapAttrsRecursive (
          path: package-data:
          let
            package-fn = package-data.default or package-data;
          in
          if isFunction package-fn || isPath package-fn || isString package-fn then
            callPackage package-fn (
              self
              // {
                inherit inputs;
              }
            )
          else
            package-data
        ) package-fns
      );

      supported-packages = filterAttrs (
        _name: package: package != null && (!(package ? meta.platforms) || availableOn hostPlatform package)
      ) built-packages;
    in
    {
      packages = supported-packages;
    };
}
