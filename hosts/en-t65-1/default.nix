{ config, pkgs, lib, ...}: {
  imports = [
    ./hardware.nix
    ./secrets.nix
    ../../common/server.nix
    ../../common/nas.nix
    ./minecraft.nix
    ../../common/optional/nvidia.nix
  ];

  sops.secrets.syncthing-key.sopsFile = ./secrets.sops.yaml;
  sops.secrets.syncthing-cert.sopsFile = ./secrets.sops.yaml;

  system.stateVersion = "24.05";

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
