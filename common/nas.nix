{ config, lib, pkgs, outputs, ... }: let
  domain   = config.networking.hostName;
  hostname = config.networking.domain;
in {
  imports = [
    ./default.nix
    ./server.nix
  ];

  #region Drive Configuration
  services.nfs = {
    server = {
      enable            = true;
      hostName          = "nfs.${hostname}.${domain}";
      createMountPoints = true;
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
