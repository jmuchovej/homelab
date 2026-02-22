{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "hardware.storage.btrfs";
  description = "le support for btrfs devices";
  options =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
      inherit (lib.rebellion.options) mk-enable';
    in
    {
      auto-scrub = mk-enable' "btrfs autoScrub";
      dedupe = mk-enable' "btrfs deduplication";
      dedupe-filesystems = mkOption {
        type = with types; (listOf str);
        default = [ ];
        description = "Unique btrfs filesystems to dedupe.";
      };
      scrub-mounts = mkOption {
        type = with types; (listOf path);
        default = [ ];
        description = "Btrfs mount paths to scrub.";
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
      inherit (lib) mkIf genAttrs getExe;
      inherit (cfg) dedupe-filesystems;

      dedupe-fs-attrset = genAttrs dedupe-filesystems (name: {
        spec = "LABEL=${name}";
        hashTableSizeMB = 1024;
        verbosity = "info";
        workDir = ".beeshome";
        extraOptions = [
          "--thread-factor"
          "0.1"
          "--loadavg-target"
          "5"
        ];
      });
    in
    {
      environment.systemPackages = with pkgs; [
        btdu
        btrfs-assistant
        btrfs-snap
        compsize
        snapper
      ];

      services = {
        btrfs = {
          autoScrub = mkIf cfg.auto-scrub.enable {
            enable = true;
            fileSystems = mkIf (builtins.length cfg.scrub-mounts > 0) cfg.scrubMounts;
            interval = "weekly";
          };
        };

        beesd = mkIf cfg.dedupe.enable {
          filesystems = mkIf (builtins.length dedupe-filesystems > 0) dedupe-fs-attrset;
        };
      };

      systemd.services.cpulimit-bees = {
        inherit (cfg.dedupe) enable;
        after = [ "sysinit.target" ];
        description = "CPU Limit Bees";
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${getExe pkgs.cpulimit} -e bees -l 20";
          Restart = "always";
        };
      };
    };
}
