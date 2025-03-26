{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.suites.common;
in
{
  options.${namespace}.suites.common = {
    enable = mkEnableOption "`common` suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
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
