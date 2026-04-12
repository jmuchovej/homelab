_: {
  rbn.system._.hardware._.storage._.zfs = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.zfs ];
        boot.supportedFilesystems = [ "zfs" ];
        boot.zfs.allowHibernation = false;
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
