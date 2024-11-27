{ config, lib, pkgs, ...}: {
  #region Setup networking
  networking = {
    useDHCP     = lib.mkDefault true;
    useNetworkd = lib.mkDefault true;

    hostName                      = config.sops.secrets.host.value.name;
    domain                        = config.sops.secrets.shared.value.domain;
    usePredictableInterfaceNames  = true;

    networkmanager = {
      enable  = lib.mkDefault false;
    };

    # reverse filtering fix for wireguard / tailscale
    firewall = {
      checkReversePath  = "loose";
    };

    nftables = {
      enable  = true;
    };
  };

  services.resolved = {
    enable      = true;
    fallbackDns = [ "9.9.9.9" "149.112.112.112" ];
  };
  #endregion
}
