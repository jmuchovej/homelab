{
    # Snowfall Lib provides a customized `lib` instance with access to your flake's library
    # as well as the libraries available from your flake's inputs.
    lib,
    # An instance of `pkgs` with your overlays and packages applied is also available.
    pkgs,
    # You also have access to your flake's inputs.
    inputs,

    # Additional metadata is provided by Snowfall Lib.
    namespace, # The namespace used for your flake, defaulting to "internal" if not set.
    system, # The system architecture for this host (eg. `x86_64-linux`).
    target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
    format, # A normalized name for the system target (eg. `iso`).
    virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
    systems, # An attribute map of your defined hosts.

    # All other arguments come from the system system.
    config,
    ...
}: let
  inherit (lib.${namespace}) enabled disabled;
in {
  imports = [ ./hardware.nix ];

  topology.self = {
    name = "🚀 da-vcx-1";
    hardware.info = "Intel i7-11700K; 128GB RAM; NVIDIA RTX 3090";
  };

  networking.hostId = "6926372e";

  ${namespace} = {
    hardware = {
      cpu.intel = enabled;
      gpu.nvidia = enabled;
      storage = {
        enable      = true;
        ssd.enable  = true;
        zfs = {
          enable                = true;
          auto-snapshot.enable  = true;
        };
      };
    };
    security = {
      sops = enabled;
      sudo = enabled;
    };
    services = {
      ldap      = enabled;
      openssh   = enabled;
      syncthing = enabled;
      tailscale = enabled;
    };
    nix    = enabled;
    system = {
      boot        = {
        enable      = true;
        plymouth    = enabled;
        secure-boot = disabled;
        silent-boot = enabled;
      };
      locale      = enabled;
      networking  = enabled;
    };
    virtualization = {
      containers = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.05";
  # ======================== DO NOT CHANGE THIS ========================
}
