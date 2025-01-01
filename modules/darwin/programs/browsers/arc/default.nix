{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.browsers.arc;
in
{
  options.${namespace}.programs.browsers.arc = {
    enable = mkEnableOption "Arc Browser";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.arc-browser ];
  };
}
