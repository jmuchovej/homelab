{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  # You also have access to your flake's inputs.
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  system, # The system architecture for this host (eg. `x86_64-linux`). # The Snowfall Lib target for this system (eg. `x86_64-iso`). # A normalized name for the system target (eg. `iso`). # A boolean to determine whether this system is a virtual target using nixos-generators. # An attribute map of your defined hosts.
  # All other arguments come from the system system.
  ...
}:
let
  inherit (lib.${namespace}) enabled disabled;
in
{
  imports = [ ./disks.nix ./hardware.nix ];

  topology.self = {
    name = "🚀 da-vcx-1";
    hardware.info = "Intel i7-11700K; 128GB RAM; NVIDIA RTX 3090";
  };

  ${namespace} = {
    hardware = {
      cpu.intel = enabled;
      gpu.nvidia = enabled;
      storage = enabled // {
        ssd = enabled;
        btrfs = enabled;
        zfs = enabled // {
          auto-snapshot = enabled;
          pools = [ "impulse" "warp" ];
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

    nix = enabled;

    system = {
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

    services.kubernetes = enabled // {
      cidr = {
        cluster = "10.69.0.0/16";
        service = "10.70.0.1/16";
      };
      is-first = true;
      role = "server";
      # Opt for Cilium
      services.kube-proxy = disabled;
      services.flannel    = disabled;
      services.flux       = enabled;
      services.service-lb = disabled;
      services.traefik    = disabled;
      services.local-io   = disabled;
      services.metrics    = disabled;
      services.coredns    = disabled;
      helm = enabled // {
        completed-if = "get CustomResourceDefinition -A | grep -q 'cilium.io'";
      };
      minio = enabled // {
        buckets = [ "volsync" "postgres" ];
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
