{
  config,
  # inputs,
  lib,
  pkgs,
  # system,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.desktop.kitty;
  desktop = config.${namespace}.desktop.kitty;
in {
  options.${namespace}.desktop.kitty = {
    enable = mkEnableOption "Kitty";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    programs.kitty = {
      enable = true;
      package = pkgs.kitty;
    };
  };
}
