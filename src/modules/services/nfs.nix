{
  den.schema.host = { lib, ... }: {
    options.nfs =
      let
        inherit (lib) mkOption;
        inherit (lib.types)
          listOf
          nullOr
          submodule
          str
          ;
      in
      {
        exports = mkOption {
          type = listOf (submodule {
            options = {
              path = mkOption {
                type = str;
                description = "Filesystem path to export, e.g. /impulse/k8s.";
              };
              clients = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Client match (CIDR or hostname). Null resolves to this
                  host's own lab CIDR, which differs per datacenter.
                '';
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
                description = "NFS server address, e.g. 10.32.10.1 (da-gr75).";
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

  rbn.services._.nfs.nixos =
    {
      host,
      lib,
      config,
      pkgs,
      inputs,
      ...
    }:
    let
      enable-exports = host.nfs.exports != [ ];
      enable-mounts = host.nfs.mounts != [ ];

      topology = lib.rbn.from-yaml "${inputs.self}/src/topology.yaml" { inherit pkgs; };
      lab-cidr = topology.networks.${host.datacenter}.lab.cidr;
    in
    {
      services.nfs.server = lib.mkIf enable-exports {
        enable = true;
        exports =
          (lib.concatMapStringsSep "\n" (
            e: "${e.path} ${if e.clients == null then lab-cidr else e.clients}(${e.options})"
          ) host.nfs.exports)
          + "\n";
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
          # each list element becomes its own `ExecStart=` line, so the full
          # command must be a single string — bare flags are silently ignored
          exec-start' = lib.concatStringsSep " " (
            [
              "${config.systemd.package}/bin/systemd-tmpfiles"
              "--create"
              "--remove"
              "--boot"
            ]
            ++ map (mount: "--exclude-prefix=${mount}") mounts
          );
        in
        lib.mkIf enable-mounts [
          "" # reset the upstream ExecStart before redefining it
          exec-start'
        ];
    };
}
