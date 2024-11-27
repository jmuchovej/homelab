{ config, lib, pkgs, outputs, ... }: let
  domain   = config.sops.secrets.shared.value.domain;
  hostname = config.sops.secrets.host.value.hostname;
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

  security.pam = {
    zfs = {
      enable    = true;
      homes     = "impulse/homes";
      noUnmount = true;
    };
  };
  #endregion
}
