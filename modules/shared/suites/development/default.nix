{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.rebellion.suites.development;
in {
  options.rebellion.suites.development = {
    enable = mkEnableOption "`development` configuration";
  };

  config =
    mkIf cfg.enable {
    };
}
