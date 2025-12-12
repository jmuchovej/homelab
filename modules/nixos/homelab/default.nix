{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.rebellion.homelab;
in
{
  options.rebellion.homelab = {
    enable = mkEnableOption "homelab";
  };

  config = mkIf cfg.enable {
  };
}
