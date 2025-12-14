{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file enabled;

  cfg = config.rebellion.suites.common;
in
{
  imports = [
    (get-file "modules/common/suites/common.nix")
  ];

  config = mkIf cfg.enable {
    rebellion = {
      nix = enabled;

      system = {
        boot = enabled;
        locale = enabled;
        networking = enabled;
      };

      services.openssh = enabled;
      services.sops = enabled;
    };

    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
    ];
  };
}
