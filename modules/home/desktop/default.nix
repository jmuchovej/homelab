{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.suites.common;
in {
  # This is almost exclusively for hierarchy. Nothing should really go here!
  options.${namespace}.desktop = {
    enable = mkEnableOption "desktop configuration for home-manager";
  };
}
