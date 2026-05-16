_: {
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) listOf submodule str;
    in
    {
      options.nfs = {
        exports = mkOption {
          type = listOf (submodule {
            options = {
              path = mkOption {
                type = str;
                description = "Filesystem path to export, e.g. /impulse/k8s.";
              };
              clients = mkOption {
                type = str;
                default = "10.69.0.0/16";
                description = "Client match (CIDR or hostname).";
              };
              options = mkOption {
                type = str;
                default = "rw,sync,no_subtree_check,no_root_squash,crossmnt";
                description = ''
                  NFS export options. `crossmnt` lets NFSv4 traverse ZFS child
                  datasets under the export root.
                '';
              };
            };
          });
          default = [ ];
          description = "Paths to export over NFS.";
        };

        mounts = mkOption {
          type = listOf (submodule {
            options = {
              server = mkOption {
                type = str;
                description = "NFS server address, e.g. 10.69.10.1 (da-gr75).";
              };
              remote = mkOption {
                type = str;
                description = "Remote export path on the server, e.g. /impulse/home.";
              };
              local = mkOption {
                type = str;
                description = "Local mountpoint, e.g. /home.";
              };
              options = mkOption {
                type = listOf str;
                default = [
                  "nfsvers=4.2"
                  "_netdev"
                  "noatime"
                  "hard"
                  "x-systemd.automount"
                  "x-systemd.mount-timeout=10s"
                  "x-systemd.idle-timeout=600"
                  "nofail"
                ];
                description = "Mount options for this NFS filesystem.";
              };
            };
          });
          default = [ ];
          description = "Remote NFS exports to mount on this host.";
        };
      };
    };

  rbn.services._.nfs = {
    nixos =
      {
        host,
        lib,
        config,
        ...
      }:
      let
        enable-exports = host.nfs.exports != [ ];
        enable-mounts = host.nfs.mounts != [ ];
      in
      {
        services.nfs.server = lib.mkIf enable-exports {
          enable = true;
          exports =
            (lib.concatMapStringsSep "\n" (e: "${e.path} ${e.clients}(${e.options})") host.nfs.exports) + "\n";
        };
        networking.firewall.allowedTCPPorts = lib.mkIf enable-exports [ 2049 ];

        fileSystems = lib.listToAttrs (
          map (
            m:
            lib.nameValuePair m.local {
              device = "${m.server}:${m.remote}";
              fsType = "nfs";
              inherit (m) options;
            }
          ) host.nfs.mounts
        );

        systemd.services.systemd-tmpfiles-setup.serviceConfig.ExecStart =
          let
            mounts = [ "/dev" ] ++ map (m: m.local) host.nfs.mounts;
            exec-start' = [
              "" # reset the upstream ExecStart before redefining it
              "${config.systemd.package}/bin/systemd-tmpfiles"
              "--create"
              "--remove"
              "--boot"
            ]
            ++ map (mount: "--exclude-prefix=${mount}") mounts;
          in
          lib.mkIf enable-mounts exec-start';
      };
  };
}
