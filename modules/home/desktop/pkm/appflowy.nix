{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf optionals mkEnableOption;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.desktop.appflowy;
  desktop = config.rebellion.desktop;
in {
  options.rebellion.desktop.appflowy = {
    enable = mkEnableOption "AppFlowy";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    home.packages = [pkgs.appflowy];
  };
}
