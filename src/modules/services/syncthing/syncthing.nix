_:
let
  syncthing-network = import ./_network.nix;
in
{
  rbn.services._.syncthing = {
    nixos =

      {
        host,
        lib,
        config,
        ...
      }:
      let
        inherit (host) hostname;
        inherit (lib.attrsets) filterAttrs mapAttrs attrNames;

        target-devices = filterAttrs (h: _: h != hostname) syncthing-network.devices;
        devices = mapAttrs (_: runtimeID: {
          enable = true;
          id = runtimeID;
        }) target-devices;

        folders = mapAttrs (_: params: {
          enable = true;
          inherit (params) id path;
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
            inherit devices folders;
          };
        };
      };

    homeManager =
      { config, ... }:
      {
        services.syncthing = {
          enable = true;
          extraOptions = [
            "-data-dir=${config.home.homeDirectory}/Documents"
          ];
        };
      };
  };
}
