{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.${namespace}.homelab;
in
{
  options.${namespace}.homelab = {
    enable = mkEnableOption "homelab";
  };

  config = mkIf cfg.enable {
  };
}
