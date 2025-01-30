{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.suites.research;
in {
  options.${namespace}.suites.research = {
    enable = mkEnableOption "`research` configuration";
  };

  config =
    mkIf cfg.enable {
    };
}
