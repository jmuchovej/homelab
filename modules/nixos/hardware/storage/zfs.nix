{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "hardware.storage.zfs";
  description = "ZFS";
  options =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
      inherit (lib.rebellion) mkopt-enable;
    in
    {
      auto-snapshot = {
        enable = mkopt-enable "ZFS auto-snapshotting";
      };
      pools = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "ZFS Pools to manage.";
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
      inherit (lib) mkIf;
      inherit (lib.rebellion) enabled;
    in
    {
      environment.systemPackages = [ pkgs.zfs ];

      boot.supportedFilesystems = [ "zfs" ];

      boot.zfs = {
        allowHibernation = false;
        extraPools = cfg.pools;
      };

      services.zfs = {
        autoSnapshot = mkIf cfg.auto-snapshot.enable (
          enabled
          // {
            flags = "-k -p";
            frequent = 12;
            daily = 10;
            weekly = 7;
            hourly = 48;
            monthly = 24;
          }
        );

        autoScrub = enabled // {
          interval = "monthly";
          inherit (cfg) pools;
        };

        trim = {
          enable = true;
          interval = "daily";
          randomizedDelaySec = "4h";
        };
      };
    };
}
