{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "hardware";
  description = "No-op for setting up hierarchy.";
  options = with lib.rebellion.options; {
    cpu = mk-enable' "cpu";
    gpu = mk-enable' "gpu";
    storage.ssd = mk-enable "support for SSDs" true;
  };
  config =
    { cfg, pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        btrfs-progs
        fuseiso
        nfs-utils
        ntfs3g
      ];

      services.fstrim.enable = lib.mkDefault cfg.storage.ssd.enable;
    };
}
