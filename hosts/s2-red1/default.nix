{ config, pkgs, lib, ...}: {
  imports = [
    ./hardware.nix
    ../../common/server.nix
    ../../common/nas.nix
  ];

  system.stateVersion = "24.05";

  sops.secrets.host = {
    file        = ./secrets.sops.yaml;
    format      = "yaml";
    parseValue  = true;
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  time.timeZone = "America/New_York";

  #region Drive Configuration
  boot.zfs = {
    enabled         = true;
    extraPools      = [ "impulse" "warp" ];
    allowHiberation = false;
    forceImportAll  = true;
  };

  services.zfs = {
    autoSnapshot = {
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
      pools     = [ "impulse" "warp" ];
      interval  = "monthly";
    };

    trim = {
      enable              = true;
      interval            = "daily";
      randomizedDelaySec  = "4h";
    };
  };

  services.qemuGuest.enable = true;

  services.nfs.exports = [
  ];
  #endregion
}
