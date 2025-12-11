{
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
  inherit (builtins)
    pathExists
    attrNames
    readDir
    ;

  overlays-path = ../overlays;
  dynamic-overlays-set =
    if !(pathExists overlays-path) then
      { }
    else
      let
        overlay-dirs = attrNames (readDir overlays-path);
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
      package-fns = prev.lib.filesystem.packagesFromDirectoryRecursive {
        inherit directory;
        callPackage = file: _args: import file;
      };
    in
    {
      rebellion = prev.lib.fix (
        self:
        prev.lib.mapAttrs (_name: func: final.callPackage func (self // { inherit inputs; })) package-fns
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
