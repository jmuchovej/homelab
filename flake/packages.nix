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

      # Check if a package-data attrset declares platforms that exclude the current host.
      # This is checked *before* callPackage to avoid abort on missing deps.
      # `platforms` can be a list or a function that receives `lib`.
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
    in
    {
      packages = supported-packages;
    };
}
