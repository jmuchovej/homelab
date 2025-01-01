{ config, lib, pkgs, namespace, ...  }: let
  inherit (lib) mkIf mkDefault mkEnableOption;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.suites.networking;
in
{
  options.${namespace}.suites.networking = {
    enable = mkEnableOption "`networking` configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services = {
        tailscale = mkDefault enabled;
      };

      system = {
        networking = mkDefault enabled;
      };
    };
  };
}
