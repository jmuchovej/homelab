{ config, pkgs, lib, ...  }: let
  domain      = config.sops.secrets.shared.value.domain;
  hostname    = config.sops.secrets.host.value.hostname;
  datacenter  = config.sops.secrets.host.value.datacenter;
  k8s-secrets = (builtins.getAttr
    config.sops.secrets.shared
    datacenter
  ).kubernetes;
in {
  imports = [ ./firewall.nix ];

  services.k3s = {
    enable = true;
    role = "server";
    token = lib.mkDefault k8s-secrets.agent.node-token;
    extraFlags = "--tls-san ${hostname}.${datacenter}.${domain} --disable servicelb --disable traefik --disable local-storage --flannel-backend=host-gw --node-taint \"node-role.kubernetes.io/master=true:NoSchedule\" --node-label \"k3s-upgrade=false\"";
    extraKubeletConfig = {
      imageMaximumGCAge = "168h";
    };
  };

  programs.nbd.enable = true;

  environment.systemPackages = with pkgs; [ k3s kubectl ];
}
