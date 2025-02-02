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

  cfg = config.${namespace}.desktop.rio;
  desktop = config.${namespace}.suites.desktop;
in {
  options.${namespace}.desktop.rio = {
    enable = mkEnableOption "Rio";
  };

  config = mkIf cfg.enable && desktop.enable {
    programs.rio = {
      enable = true;
      package = pkgs.rio;
    };
  };
}
