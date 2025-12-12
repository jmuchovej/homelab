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

  cfg = config.rebellion.desktop.alacritty;
  desktop = config.rebellion.desktop;
in {
  options.rebellion.desktop.alacritty = {
    enable = mkEnableOption "Alacritty";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    programs.alacritty = {
      enable = true;
      package = pkgs.alacritty;
    };
  };
}
