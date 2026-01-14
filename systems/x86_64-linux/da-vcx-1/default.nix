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
        ollama.models = [
          "embeddinggema"
          "qwen3-embedding"
          "all-minilm"
          "deepseek-r1"
          "deepseek-v3.1"
          "qwen2.5-coder"
          "qwen2.5"
          "phi3"
          "phi"
          "phi3.5"
          "qwen"
          "qwen2"
          "codellamma"
          "dolphin3"
          "olmo2"
          "deepseek-v3"
          "deepseek-coder"
          "codegemma"
          "falcon3"
          "qwq"
          "qwen2.5vl"
          "phi"
          "phi4-reasoning"
          "llama3.3"
          "qwen3"
          "qwen3-vl"
          "magistral"
          "ministral-3"
          "gemma"
          "gemma2"
          "gemma3"
          "llava"
          "llama3.2-vision"
          "nemotron-3-nano"
          "gpt-oss"
          "mistral"
          "mixtral"
          "cogito"
          "llama4"
          "devstral"
          "devstral-2"
          "llama3.2"
          "llama3.1"
          "llama3"
          "nomic-embed-text"
          "mxbai-embed-large"
          "olmo-3"
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
