{ config, pkgs, lib, ...  }: let
  datacenter  = config.sops.secrets.host.value.datacenter;
  k8s-secrets = (builtins.getAttr
    config.sops.secrets.shared
    datacenter
  ).kubernetes;
in {
  imports = [ ./firewall.nix ];

  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = lib.mkDefault k8s-secrets.server.addr;
    token = lib.mkDefault k8s-secrets.agent.node-token;
    # Optionally add additional args to k3s
    extraFlags = "--node-label \"k3s-upgrade=false\"";
    extraKubeletConfig = {
      imageMaximumGCAge = "168h";
    };
  };

  # https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/#nixos
  systemd.services.containerd.serviceConfig = {
    LimitNOFILE = lib.mkForce null;
  };

  programs.nbd.enable = true;

  environment.systemPackages = with pkgs; [ k3s ];
}
