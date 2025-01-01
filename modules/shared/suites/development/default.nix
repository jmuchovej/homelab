{ config, lib, pkgs, namespace, ...  }: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.suites.development;
in
{
  options.${namespace}.suites.development = {
    enable = mkEnableOption "`development` configuration";
  };

  config = mkIf cfg.enable {
  };
}
