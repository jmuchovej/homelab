{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.common";
  always-active = true;
  imports = [ (lib.rebellion.fs.get-file "modules/_common/suites/common.nix") ];
  config =
    { lib, pkgs, ... }:
    let
      inherit (lib.rebellion) enabled;
    in
    {
      rebellion = {
        system = {
          networking = enabled;
        };

        services.openssh = enabled;
        security.sops = enabled;
      };

      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
      ];
    };
}
