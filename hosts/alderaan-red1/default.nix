{ config, pkgs, lib, ...}: {
  imports = [
    ./hardware.nix
    ../../common/server.nix
    ../../common/nas.nix
  ];

  system.stateVersion = "24.05";

  # machine = import ./machine.nix;

  networking = {
    hostName  = "red1-alderaan";
    domain    = "jmuchovej.com";
  };

  # Bootloader
  boot.loader = {
    systemd-boot.enable       = true;
    efi.canTouchEfiVariables  = true;
    timeout                   = 10;
  };

  time.timeZone = "America/New_York";

  #region Drive Configuration
  boot.zfs.extraPools           = [ "impulse" "warp" ];
  services.zfs.autoScrub.pools  = [ "impulse" "warp" ];
  services.qemuGuest.enable     = true;
  # services.nfs.exports          = [
  # ];
  #endregion
}
