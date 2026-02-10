{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.suites.networking;
in
{
  options.rebellion.suites.networking = {
    enable = mkEnableOption "`networking` configuration";
  };

  config = mkIf cfg.enable {
    rebellion = {
      services = {
        tailscale = mkDefault enabled;
      };

      system = {
        networking = mkDefault enabled;
      };
    };
  };
}
