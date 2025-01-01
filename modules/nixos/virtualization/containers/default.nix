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
  inherit (lib) types mkDefault mkEnableOption mkIf;

  cfg = config.${namespace}.virtualization.containers;
in
{
  options.${namespace}.virtualization.containers = with types; {
    enable = mkEnableOption "[OCI] Containers";
  };

  config = mkIf cfg.enable {
    virtualisation = {
      containers.enable       = true;
      oci-containers.backend  = "podman";
      podman = {
        enable                              = true;
        dockerCompat                        = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    # Useful other development tools
    environment.systemPackages = with pkgs; [
      apptainer
      dive # look into docker image layers
      podman-tui # status of containers in the terminal
      # docker-compose # start group of containers for dev
      podman-compose # start group of containers for dev
    ];

    hardware.nvidia-container-toolkit = {
      enable = config.${namespace}.hardware.gpu.nvidia.enable;
    };
  };
}
