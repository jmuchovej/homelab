{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.desktop;
in {
  # This is almost exclusively for hierarchy. Nothing should really go here!
  options.rebellion.desktop = {
    enable = mkEnableOption "desktop configuration for home-manager";
  };
}
