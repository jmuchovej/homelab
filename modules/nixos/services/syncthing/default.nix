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
    host,

    # All other arguments come from the system system.
    config,
    ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  inherit (lib.attrsets) filterAttrs mapAttrs attrNames;

  cfg = config.${namespace}.services.syncthing;

  sync-secrets = import ./secrets.nix;
  filtered-devices = filterAttrs (key: val: key != host) sync-secrets.devices;
  device-map = mapAttrs (node: node-id: { id = node-id; }) filtered-devices;

  folder-map = mapAttrs (folder-id: folder: {
    id      = folder.id;
    path    = folder.path;
    type    = "sendreceive";
    enable  = true;
    devices = attrNames device-map;
    versioning  = {
      type    = "staggered";
      fsPath  = ".stversions";
      params  = {
        cleanInterval = "3600";
        maxAge        = "63072000";  # 730 days
      };
    };
  }) sync-secrets.folders;
in {
  options.${namespace}.services.syncthing = with types; {
    enable = mkEnableOption "syncthing";
    runtimeID = mkOption {
      type        = str;
      description = "This machine's Syncthing ID.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

    networking.firewall.allowedTCPPorts = [ 8384 ];

    sops.secrets."syncthing/key".sopsFile = (
      lib.snowfall.fs.get-file "secrets/systems/${host}.sops.yaml"
    );
    sops.secrets."syncthing/cert".sopsFile = (
      lib.snowfall.fs.get-file "secrets/systems/${host}.sops.yaml"
    );

    services.syncthing = {
      enable = true;

      guiAddress = "0.0.0.0:8384";

      key   = config.sops.secrets."syncthing/key".path;
      cert  = config.sops.secrets."syncthing/cert".path;

      overrideFolders   = true;
      overrideDevices   = false;
      openDefaultPorts  = true;

      settings = {
        devices = device-map;
        folders = folder-map;
      };
    };
  };
}
