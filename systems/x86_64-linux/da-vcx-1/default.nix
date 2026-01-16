{ lib, pkgs, ... }:
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
        ollama.package = pkgs.ollama-cuda;
        ollama.models = [
          "all-minilm"
          "codegemma"
          "codellamma"
          "cogito"
          "deepseek-coder"
          "deepseek-r1"
          "deepseek-v3"
          "deepseek-v3.1"
          "devstral"
          "devstral-2"
          "dolphin3"
          "falcon3"
          "gemma"
          "gemma2"
          "gemma3"
          "gpt-oss"
          "llama3"
          "llama3.1"
          "llama3.2"
          "llama3.2-vision"
          "llama3.3"
          "llama4"
          "llava"
          "magistral"
          "ministral-3"
          "mistral"
          "mixtral"
          "mxbai-embed-large"
          "nemotron-3-nano"
          "nomic-embed-text"
          "olmo-3"
          "olmo2"
          "phi"
          "phi"
          "phi3"
          "phi3.5"
          "phi4-reasoning"
          "qwen"
          "qwen2"
          "qwen2.5"
          "qwen2.5-coder"
          "qwen2.5vl"
          "qwen3"
          "qwen3-embedding"
          "qwen3-vl"
          "qwq"
          "embeddinggema"
        ];
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
    services.chroma = enabled;
    services.authentik = enabled;
    services.cloudflared = enabled;
    services.traefik = enabled;
    services.home-assistant = enabled;
    services.media = enabled;
    services.postgres = enabled;
    services.arr = enabled;
    services.homebox = enabled;

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

    suites = {
      server = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
