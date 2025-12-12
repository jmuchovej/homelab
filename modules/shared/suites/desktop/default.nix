{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.rebellion.suites.desktop;
in {
  options.rebellion.suites.desktop = {
    enable = mkEnableOption "`desktop` configuration";
  };

  config =
    mkIf cfg.enable {
    };
}
