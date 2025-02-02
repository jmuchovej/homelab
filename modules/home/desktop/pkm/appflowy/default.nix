{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf optionals mkEnableOption;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.desktop.appflowy;
  desktop = config.${namespace}.suites.desktop;
in {
  options.${namespace}.desktop.appflowy = {
    enable = mkEnableOption "AppFlowy";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    home.packages = [pkgs.appflowy];
  };
}
