{ config, lib, pkgs, outputs, ... }: let
  hostname = config.networking.hostName;
  domain   = config.networking.domain;
in {
  imports = [
    ./default.nix
    ./server.nix
  ];

  boot.supportedFilesystems = [ "zfs" ];

  #region Drive Configuration
  services.nfs = {
    server = {
      enable            = true;
      hostName          = "nfs.${hostname}.${domain}";
      # createMountPoints = true;
    };
  };

  # security.pam = {
  #   zfs = {
  #     enable    = true;
  #     homes     = "impulse/homes";
  #     noUnmount = true;
  #   };
  # };
  #endregion
}
