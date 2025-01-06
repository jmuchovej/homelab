{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  # You also have access to your flake's inputs.
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set. # The system architecture for this host (eg. `x86_64-linux`). # The Snowfall Lib target for this system (eg. `x86_64-iso`). # A normalized name for the system target (eg. `iso`). # A boolean to determine whether this system is a virtual target using nixos-generators. # An attribute map of your defined hosts.
  host,
  # All other arguments come from the system system.
  config,
  options,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    types
    ;
  inherit (lib.attrsets) filterAttrs mapAttrs attrNames;

  cfg = config.${namespace}.services.syncthing;

  syncthing-network = import ./network.nix;

  target-devices = filterAttrs (hostname: _runtimeID: hostname != host) syncthing-network.devices;
  devices = mapAttrs (_hostname: runtimeID: {
    enable = true;
    id = runtimeID;
  }) target-devices;

  folders = mapAttrs (_name: params: {
    enable = true;
    inherit (params) id;
    inherit (params) path;
    type = "sendreceive";
    devices = attrNames target-devices;
    versioning = {
      type = "staggered";
      fsPath = ".stversions";
      params = {
        cleanInterval = "3600";
        maxAge = "63072000"; # 730 days
      };
    };
  }) syncthing-network.folders;

in
{
  options.${namespace}.services.syncthing = with types; {
    enable = mkEnableOption "syncthing";
  };

  config = mkIf cfg.enable {
    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

    networking.firewall.allowedTCPPorts = [ 8384 ];

    sops.secrets."syncthing/key" = { };
    sops.secrets."syncthing/cert" = { };

    services.syncthing = {
      enable = true;

      guiAddress = "0.0.0.0:8384";

      key = config.sops.secrets."syncthing/key".path;
      cert = config.sops.secrets."syncthing/cert".path;

      overrideFolders = true;
      overrideDevices = true;
      openDefaultPorts = true;

      settings = {
        inherit devices;
        inherit folders;
      };
    };
  };
}
