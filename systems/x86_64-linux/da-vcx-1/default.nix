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

    services.mesh = enabled // {
      consul = {
        server = true;
        bootstrap-expect = 1;
        interface = "enp12s0";
      };
      vip.priority = 100;
    };
    services.proton-vpn = enabled // {
      location = "SE-US#1";
    };
    services.qbittorrent = enabled;
    services.s3 = enabled // {
      data-dir = [ "/impulse/s3" ];
    };

    system = {
      nix = enabled;
      boot = enabled // {
        plymouth = enabled;
        secure-boot = disabled;
        silent-boot = enabled;
      };
      locale = enabled;
      networking = enabled // {
        dns = "dnsmasq";
        manager = "networkmanager";
      };
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

    suites = {
      server = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
