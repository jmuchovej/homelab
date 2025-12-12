{
  config,
  lib,
  namespace,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.services.tailscale;
in {
  options.rebellion.services.tailscale = {
    enable = mkEnableOption "tailscale"; # { default = true; };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
    };
  };
}
