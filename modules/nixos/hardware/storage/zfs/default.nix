{ config, pkgs, lib, namespace, ... }: let
  inherit (lib) types mkIf mkOption mkEnableOption;

  cfg = config.${namespace}.hardware.storage.zfs;
in {
  options.${namespace}.hardware.storage.zfs = with types; {
    enable = mkEnableOption "ZFS";
    auto-snapshot = {
      enable = mkEnableOption "ZFS auto-snapshotting";
    };
    pools = mkOption {
      type        = listOf str;
      default     = [ ];
      description = "ZFS Pools to manage.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.zfs ];

    boot.supportedFilesystems = [ "zfs" ];

    boot.zfs = {
      # enabled           = true;
      allowHibernation  = false;
      forceImportAll    = true;
    };

    services.zfs = {
      autoSnapshot = mkIf cfg.auto-snapshot.enable {
        flags     = "-k -p";
        enable    = true;
        frequent  = 12;
        daily     = 10;
        weekly    =  7;
        hourly    = 48;
        monthly   = 24;
      };

      autoScrub = {
        enable    = true;
        interval  = "monthly";
        inherit (cfg) pools;
      };

      trim = {
        enable              = true;
        interval            = "daily";
        randomizedDelaySec  = "4h";
      };
    };
  };
}
