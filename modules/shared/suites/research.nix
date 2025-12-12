{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.rebellion.suites.research;
in {
  options.rebellion.suites.research = {
    enable = mkEnableOption "`research` configuration";
  };

  config =
    mkIf cfg.enable {
    };
}
