{ config, pkgs, lib, ...}: {
  imports = [
    ./hardware.nix
    ./secrets.nix
    ../../common/server.nix
    ../../common/nas.nix
  ];

  system.stateVersion = "24.05";

  sops.secrets.syncthing-key.sopsFile = ./secrets.sops.yaml;
  sops.secrets.syncthing-cert.sopsFile = ./secrets.sops.yaml;

  time.timeZone = "America/New_York";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  services.qemuGuest.enable = true;
}
