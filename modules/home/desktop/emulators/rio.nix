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

  cfg = config.rebellion.desktop.rio;
  desktop = config.rebellion.desktop;
in {
  options.rebellion.desktop.rio = {
    enable = mkEnableOption "Rio";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    programs.rio = {
      enable = true;
      package = pkgs.rio;
    };
  };
}
