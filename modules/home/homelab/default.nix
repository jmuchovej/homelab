{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.homelab;
in {
  options.${namespace}.homelab = {
    enable = mkEnableOption "`homelab` suite";
  };

  config = mkIf cfg.enable {
  };
}
