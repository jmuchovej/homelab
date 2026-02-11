{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  namespace = "system";
  description = "manage booting";
  options =
    { lib, ... }:
    let
      inherit (lib.rebellion) mkopt-enable;
    in
    {
      boot = {
        plymouth = {
          enable = mkopt-enable "plymouth boot splash";
        };
        secure-boot = {
          enable = mkopt-enable "secure boot";
        };
        silent-boot = {
          enable = mkopt-enable "silent boot";
        };
      };
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) optionals;
      inherit (lib.rebellion) default-attrs;
    in
    {
      environment.systemPackages =
        with pkgs;
        [
          efibootmgr
          efitools
          efivar
        ]
        ++ optionals cfg.boot.secure-boot.enable [ sbctl ];

      boot = {
        kernelParams =
          optionals cfg.boot.plymouth.enable [ "quiet" ]
          ++ optionals cfg.boot.silent-boot.enable [
            # tell the kernel to not be verbose
            "quiet"

            # kernel log message level
            "loglevel=3" # 1: system is unusable | 3: error condition | 7: very verbose

            # udev log message level
            "udev.log_level=3"

            # lower the udev log level to show only errors or worse
            "rd.udev.log_level=3"

            # disable systemd status messages
            # rd prefix means systemd-udev will be used instead of initrd
            "systemd.show_status=auto"
            "rd.systemd.show_status=auto"

            # disable the cursor in vt to get a black screen during intermissions
            "vt.global_cursor_default=0"
          ];

        # TODO implement secure boot
        # lanzaboote = mkIf cfg.boot.secure-boot.enable {
        #   enable = true;
        #   pkiBundle = "/etc/secureboot";
        # };

        loader = {
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
          };

          generationsDir.copyKernels = true;

          systemd-boot = {
            enable = !cfg.boot.secure-boot.enable;
            configurationLimit = 20;
            # https://github.com/NixOS/nixpkgs/blob/d49da4/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix#L215-L221
            editor = false;
          };
        };

        plymouth = {
          inherit (cfg.boot.plymouth) enable;
          # theme = "${themecfg.boot.selectedTheme.name}-${themecfg.boot.selectedTheme.variant}";
          # themePackages = [ pkgs.catppuccin-plymouth ];
        };

        tmp = default-attrs {
          useTmpfs = true;
          cleanOnBoot = true;
          tmpfsSize = "50%";
        };
      };

      # services.fwupd = {
      #   enable = true;
      #   daemonSettings.EspLocation = config.boot.loader.efi.efiSysMountPoint;
      # };
    };
}
