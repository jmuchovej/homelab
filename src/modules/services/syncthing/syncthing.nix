{ __findFile, ... }:
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
        inherit (lib) elem filter;
        inherit (lib.attrsets) filterAttrs mapAttrs attrNames;
        inherit (syncthing-network)
          devices
          folders
          servers
          clients
          ;

        is-server = elem hostname servers;
        client-owner = clients.${hostname} or null;

        # Folders this host actually syncs. Servers mirror everything; clients
        # only mirror the folder belonging to their assigned owner.
        selected-folders =
          if is-server then folders else filterAttrs (_: f: f.owner == client-owner) folders;

        # Per-folder peer list: every server plus the client(s) whose owner
        # matches the folder's owner.
        folder-peers = f: servers ++ attrNames (filterAttrs (_: o: o == f.owner) clients);

        # Peers this host pins. Strip self so Syncthing doesn't try to dial
        # itself.
        peer-devices = filterAttrs (h: _: h != hostname) devices;

        device-config = mapAttrs (nodename: id: {
          inherit id;
          addresses = [
            "tcp://${nodename}:22000"
            "tcp://syncthing.${nodename}.jm0.io:22000"
          ];
        }) peer-devices;

        folder-config = mapAttrs (_: f: {
          inherit (f) id;
          # Servers keep mirrors under the syncthing service dir, so they
          # don't require the LDAP-provisioned home directories to exist.
          # Clients sync into the owner's home.
          path = if is-server then "/var/lib/syncthing/${f.owner}" else "/home/${f.owner}/Syncthing";
          type = "sendreceive";
          devices = filter (h: h != hostname) (folder-peers f);
          versioning = {
            type = "staggered";
            fsPath = ".stversions";
            params = {
              cleanInterval = "3600";
              maxAge = "63072000"; # 730 days
            };
          };
        }) selected-folders;
      in
      {
        systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

        sops.secrets."syncthing/key" = {
          owner = config.services.syncthing.user;
        };
        sops.secrets."syncthing/cert" = {
          owner = config.services.syncthing.user;
        };

        services.syncthing = {
          enable = true;

          # GUI bound to loopback. Traefik fronts it via the
          # `<rbn/mesh/register>` include below; authentik gates access.
          guiAddress = "127.0.0.1:8384";

          key = config.sops.secrets."syncthing/key".path;
          cert = config.sops.secrets."syncthing/cert".path;

          overrideFolders = true;
          overrideDevices = true;
          openDefaultPorts = true;

          settings = {
            devices = device-config;
            folders = folder-config;
            options = {
              # All peers are pinned via the `addresses` above, so there's no
              # need to phone Syncthing's public discovery/relay servers (and
              # routing block-exchange through their relays would be a ToS
              # issue anyway).
              globalAnnounceEnabled = false;
              localAnnounceEnabled = true;
              relaysEnabled = false;
              urAccepted = -1;
            };
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

    includes = [
      (<rbn/mesh/register> {
        name = "syncthing";
        port = 8384;
        node-scoped = true;
        authed = true;
        healthcheck = "/rest/noauth/health";
        authentik = {
          name = "Syncthing";
          type = "proxy";
          group = "Admin";
          access = [ "admin" ];
          icon = "syncthing";
          skip-paths = "/rest/*";
        };
      })
    ];
  };
}
