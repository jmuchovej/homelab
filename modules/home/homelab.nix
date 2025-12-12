{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.homelab;
in {
  options.rebellion.homelab = {
    enable = mkEnableOption "`homelab` suite";
  };

  config = mkIf cfg.enable {
  };
}
