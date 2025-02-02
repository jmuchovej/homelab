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

  cfg = config.${namespace}.desktop.alacritty;
  desktop = config.${namespace}.desktop;
in {
  options.${namespace}.desktop.alacritty = {
    enable = mkEnableOption "Alacritty";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    programs.alacritty = {
      enable = true;
      package = pkgs.alacritty;
    };
  };
}
