{ inputs, lib, ... }:
{
  flake-file.inputs.lanzaboote.url = "github:nix-community/lanzaboote";

  rbn.system._.boot = {
    nixos = { lib, pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        efibootmgr
        efitools
        efivar
      ];

      boot = {
        loader = {
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
          };

          generationsDir.copyKernels = true;

          systemd-boot = {
            enable = true;
            configurationLimit = 20;
            editor = false;
          };
        };

        tmp = {
          useTmpfs = lib.mkDefault true;
          cleanOnBoot = lib.mkDefault true;
          tmpfsSize = lib.mkDefault "50%";
        };
      };
    };

    _.secure.nixos = {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
      boot = {
        loader.systemd-boot.enable = lib.mkForce false;
        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
        };
      };
    };

    _.graphical.nixos = {
      boot = {
        plymouth.enable = true;
        consoleLogLevel = 3;
        initrd.verbose = false;
        initrd.systemd.enable = true;
        kernelParams = [
          "quiet"
          "splash"
          "intremap=on"
          "boot.shell_on_fail"
          "udev.log_priority=3"
          "rd.systemd.show_status=auto"
        ];
      };
    };
  };
}
