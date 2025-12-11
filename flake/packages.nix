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
        mapAttrs
        filterAttrs
        meta
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
        mapAttrs (
          _name: package-data:
          let
            package-fn = package-data.default or package-data;
          in
          callPackage package-fn (
            self
            // {
              inherit inputs;
            }
          )
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
