{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    genAttrs
    getExe
    ;
  inherit (cfg) dedupe-filesystems;

  cfg = config.${namespace}.hardware.storage.btrfs;

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
  options.${namespace}.hardware.storage.btrfs = with types; {
    enable = mkEnableOption "le support for btrfs devices";
    auto-scrub = mkEnableOption "btrfs autoScrub";
    dedupe = mkEnableOption "btrfs deduplication";
    dedupe-filesystems = mkOption {
      type = listOf str;
      default = [ ];
      description = "Unique btrfs filesystems to dedupe.";
    };
    scrub-mounts = mkOption {
      type = listOf path;
      default = [ ];
      description = "Btrfs mount paths to scrub.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      btdu
      btrfs-assistant
      btrfs-snap
      compsize
      snapper
    ];

    services = {
      btrfs = {
        autoScrub = mkIf cfg.auto-scrub {
          enable = true;
          fileSystems = mkIf (builtins.length cfg.scrub-mounts > 0) cfg.scrubMounts;
          interval = "weekly";
        };
      };

      beesd = mkIf cfg.dedupe {
        filesystems = mkIf (builtins.length dedupe-filesystems > 0) dedupe-fs-attrset;
      };
    };

    systemd.services.cpulimit-bees = {
      enable = cfg.dedupe;
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
