{ lib, ... }:
let
  inherit (lib.rebellion) enabled disabled;
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
  ];

  topology.self = {
    name = "🚀 da-vcx-1";
    hardware.info = "Intel i7-11700K; 128GB RAM; NVIDIA RTX 3090";
  };

  rebellion = {
    hardware = {
      cpu.intel = enabled;
      gpu.nvidia = enabled;
      storage = enabled // {
        ssd = enabled;
        btrfs = enabled;
        zfs = enabled // {
          auto-snapshot = enabled;
          pools = [
            "impulse"
            "warp"
          ];
        };
      };
    };
    security = {
      sudo = enabled;
      sops = enabled // {
        defaultSopsFile = ./secrets.sops.yaml;
      };
    };
    services = {
      ldap = enabled;
      openssh = enabled;
      syncthing = enabled;
      tailscale = enabled;
      local-llms = enabled // {
        vllm.model = "Qwen/Qwen2.5-72B-Instruct";
      };
    };

    system = {
      nix = enabled;
      boot = enabled // {
        plymouth = enabled;
        secure-boot = disabled;
        silent-boot = enabled;
      };
      locale = enabled;
      networking = enabled;
    };
    virtualization = {
      containers = enabled;
    };

    homelab = {
      authentik = enabled;
      cloudflared = enabled;
      traefik = enabled;
      home-assistant = enabled;
      media = enabled;
      postgres = enabled;
      arr = enabled;
    };

    services.kubernetes = disabled // {
      cidr = {
        cluster = "10.69.0.0/16";
        service = "10.70.0.1/16";
      };
      is-first = true;
      role = "server";
      # Opt for Cilium
      services.kube-proxy = disabled;
      services.flannel = disabled;
      services.flux = enabled;
      services.service-lb = disabled;
      services.traefik = disabled;
      services.local-io = disabled;
      services.metrics = disabled;
      services.coredns = disabled;
      helm = enabled // {
        completed-if = "get CustomResourceDefinition -A | grep -q 'cilium.io'";
      };
      minio = enabled // {
        buckets = [
          "volsync"
          "postgres"
        ];
        data-dir = [ "/impulse/minio" ];
      };
    };

    suites = {
      server = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
