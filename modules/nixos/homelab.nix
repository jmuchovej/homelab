{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.homelab;
in
{
  options.rebellion.homelab = {
    enable = mkEnableOption "homelab";
  };

  config = mkIf cfg.enable {
  };
}
