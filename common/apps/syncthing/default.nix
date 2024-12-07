{ config, lib, pkgs, ... }:
let
  inherit (lib.attrsets) filterAttrs mapAttrs attrNames;
  sync-secrets = import ./secrets.nix;
  filtered-devices = filterAttrs (key: val: key != config.node.qualified-name) sync-secrets.devices;
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
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  networking.firewall.allowedTCPPorts = [ 8384 ];

  services.syncthing = {
    enable = true;

    guiAddress = "0.0.0.0:8384";

    key   = config.sops.secrets.syncthing-key.path;
    cert  = config.sops.secrets.syncthing-cert.path;

    overrideFolders   = true;
    overrideDevices   = false;
    openDefaultPorts  = true;

    settings = {
      devices = device-map;
      folders = folder-map;
    };
  };
}
