_: {
  rbn.system._.hardware._.storage._.zfs = {
    nixos =
      { lib, pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.zfs ];
        boot.supportedFilesystems = [ "zfs" ];
        boot.zfs.unsafeAllowHibernation = false;
        # Root is btrfs on these hosts, so this is purely about silencing the
        # 26.11 default-flip warning. New default is `false` (safer).
        boot.zfs.forceImportRoot = false;
        # TODO ZFS 2.3 only supports up to 6.17!
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/os-specific/linux/zfs/2_3.nix
        # Latest from https://kernel.org
        # kernelPackages = pkgs.linuxPackages_latest;
        # https://nixos.org/manual/nixos/unstable/index.html#sec-kernel-config
        # kernelPackages = pkgs.linuxKernels.packages.linux_6_12;
        # https://nixos.org/manual/nixos/unstable/index.html#sec-linux-zfs
        boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
      };

    # Auto-snapshot + scrub + trim — include via <rbn/system/hardware/storage/zfs/managed>
    # Per-host pools go in the host aspect's nixos block:
    #   boot.zfs.extraPools = [ "impulse" "warp" ];
    provides.managed.nixos = {
      services.zfs = {
        autoSnapshot = {
          enable = true;
          flags = "-k -p";
          frequent = 12;
          daily = 10;
          weekly = 7;
          hourly = 48;
          monthly = 24;
        };

        autoScrub = {
          enable = true;
          interval = "monthly";
        };

        trim = {
          enable = true;
          interval = "daily";
          randomizedDelaySec = "4h";
        };
      };
    };
  };
}
