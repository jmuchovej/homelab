{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "hardware.storage";
  description = "extra storage devices";
  options =
    { lib, ... }:
    let
      inherit (lib.rebellion) mkopt-enable;
    in
    {
      ssd = {
        enable = mkopt-enable "support for SSDs" // {
          default = true;
        };
      };
    };
  config =
    { cfg, ... }:
    {
      environment.systemPackages = with pkgs; [
        btrfs-progs
        fuseiso
        nfs-utils
        ntfs3g
      ];

      services.fstrim.enable = lib.mkDefault cfg.ssd.enable;
    };
}
