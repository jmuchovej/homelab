{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.suites.common;
in
{
  options.rebellion.suites.common = {
    enable = mkEnableOption "`common` suite";
  };

  config = mkIf cfg.enable {
    rebellion = {
      nix = enabled;

      system.boot = enabled;
      system.locale = enabled;
      system.networking = enabled;

      services.openssh = enabled;

      security.sops = enabled;
    };

    environment.systemPackages = with pkgs; [
      git
      pciutils
      usbutils
    ];
  };
}
