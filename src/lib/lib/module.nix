## Internal module discovery and wrapping.
##
## Used by system.nix and home.nix to discover user modules from a directory,
## wrap them with standard arguments (system, target, format, inputs), and
## produce an attrset of NixOS/HM module functions.
{
  lib,
  rebellion-lib,
  inputs,
}:
let
  inherit (lib)
    mapAttrs
    isFunction
    hasPrefix
    ;
  inherit (builtins)
    replaceStrings
    unsafeDiscardStringContext
    substring
    stringLength
    foldl'
    ;
in
{
  module = {
    create-modules =
      {
        src,
        overrides ? { },
        alias ? { },
      }:
      let
        user-modules = rebellion-lib.fs.get-module-files' src;
        create-module-metadata = module: {
          name =
            let
              replace-src = [
                (toString src)
                "/default.nix"
              ];
              replace-dst = map (_s: "") replace-src;
              module-str = unsafeDiscardStringContext module;
              cleaned-name = replaceStrings replace-src replace-dst module-str;
            in
            if hasPrefix "/" cleaned-name then
              substring 1 ((stringLength cleaned-name) - 1) cleaned-name
            else
              cleaned-name;
          path = module;
        };
        modules-metadata = map create-module-metadata user-modules;

        merge-modules =
          modules: metadata:
          modules
          // {
            ${metadata.name} =
              args@{ pkgs, ... }:
              let
                system = args.system or args.pkgs.stdenv.hostPlatform.system;
                target = args.system or system;

                format = if rebellion-lib.system.is-macos target then "macos" else "linux";

                modified-args = args // {
                  inherit system target format;
                  systems = args.systems or { };
                  inputs = rebellion-lib.flake.without-src inputs;
                };
                imported-user-module = import metadata.path;
                user-module =
                  if isFunction imported-user-module then
                    imported-user-module modified-args
                  else
                    imported-user-module;
              in
              user-module // { _file = metadata.path; };
          };
        modules-unaliased = foldl' merge-modules { } modules-metadata;
        modules-w-aliases = mapAttrs (_: value: modules-unaliased.${value}) alias;
        modules = modules-unaliased // modules-w-aliases // overrides;
      in
      modules;
  };
}
