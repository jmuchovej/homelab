_: {
  rbn.system._.hardware._.storage._.ssd.nixos =
    { pkgs, lib, ... }:
    {
      services.fstrim.enable = lib.mkDefault true;

      environment.systemPackages = with pkgs; [
        btrfs-progs
        fuseiso
        nfs-utils
        ntfs3g
      ];
    };
}
