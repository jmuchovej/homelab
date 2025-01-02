{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg     = config.${namespace}.programs.tools.starship;
  shells  = config.${namespace}.programs.shells;
in
{
  options.${namespace}.programs.tools.starship = {
    enable = mkEnableOption "starship";
  };

  config = mkIf cfg.enable {
    programs.starship = {
      enable  = true;
      package = pkgs.starship;
      # preset  = "jetpack";
    };
  };
}
