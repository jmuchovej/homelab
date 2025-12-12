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

  cfg = config.rebellion.desktop.kitty;
  desktop = config.rebellion.desktop.kitty;
in {
  options.rebellion.desktop.kitty = {
    enable = mkEnableOption "Kitty";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    programs.kitty = {
      enable = true;
      package = pkgs.kitty;
    };
  };
}
