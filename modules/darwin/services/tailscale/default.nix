{ config, lib, namespace, pkgs, ...  }: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.tailscale;
in
{
  options.${namespace}.services.tailscale = {
    enable = mkEnableOption "tailscale"; # { default = true; };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
    };
  };
}
