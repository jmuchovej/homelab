{
  lib,
  config,
  host,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    ;
  inherit (lib.attrsets) filterAttrs mapAttrs attrNames;

  cfg = config.rebellion.services.syncthing;

  syncthing-network = import ./syncthing-network.part.nix;

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
  options.rebellion.services.syncthing = {
    enable = mkEnableOption "syncthing";
  };

  config = mkIf cfg.enable {
    systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

    networking.firewall.allowedTCPPorts = [ 8384 ];

    sops.secrets."syncthing/key" = {
      owner = config.services.syncthing.user;
    };
    sops.secrets."syncthing/cert" = {
      owner = config.services.syncthing.user;
    };

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
