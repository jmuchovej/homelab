{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption mkOption mkMerge;
  inherit (lib.types) nullOr str;
  inherit (lib.${namespace}) enabled;
  inherit (pkgs.stdenv) isDarwin;

  cfg = config.${namespace}.nix;
in {
  options.${namespace}.nix = {
    enable = mkEnableOption "Configure nix?";
  };

  config = mkIf cfg.enable {
    nix = enabled // {
      settings = {
        use-xdg-base-directories = true;
        warn-dirty = false;
      };
    };
  };
}
