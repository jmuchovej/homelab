{ inputs, lib, ... }:
{
  flake-file.inputs.lanzaboote.url = "github:nix-community/lanzaboote";

  rbn.boot.provides.secure.nixos = {
    imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
    boot = {
      loader.systemd-boot.enable = lib.mkForce false;
      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    };
  };

  rbn.boot.provides.graphical.nixos = {
    plymouth.enable = true;
    consoleLogLevel = 3;
    initrd.verbose = false;
    initrd.systemd.enable = true;
    kernelParams = [
      "quiet"
      "splah"
      "intremap=on"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];
  };
}
