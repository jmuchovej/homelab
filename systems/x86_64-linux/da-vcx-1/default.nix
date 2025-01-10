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
        zfs = enabled // {
          auto-snapshot = enabled;
        };
      };
    };
    security = {
      sops = enabled // {
        defaultSopsFile = ./secrets.sops.yaml;
      };
      sudo = enabled;
    };
    services = {
      ldap = enabled;
      openssh = enabled;
      syncthing = enabled;
      tailscale = enabled;
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

    suites = {
      server = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
