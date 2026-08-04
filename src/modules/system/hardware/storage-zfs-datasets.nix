{
  den.schema.host = { lib, ... }: {
    options.zfs.datasets = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule {
          options = {
            quota = lib.mkOption {
              type = nullOr str;
              default = null;
              description = "Sugar for `properties.quota`, e.g. `3T`.";
            };

            owner = lib.mkOption {
              type = nullOr str;
              default = null;
              description = ''
                `chown` argument (`uid:gid` or `name:group`) for the mountpoint.
                Null leaves ownership alone, so declaring a dataset that already
                holds data is a no-op beyond ensuring it exists.
              '';
            };

            mode = lib.mkOption {
              type = nullOr str;
              default = null;
              description = "`chmod` argument for the mountpoint; null leaves it alone.";
            };

            acl-users = lib.mkOption {
              type = listOf str;
              default = [ ];
              description = ''
                authentik user keys granted `rwx` plus the inherited default.
                Each uid is read from that key's `attributes.uidNumber` in
                secrets/users.sops.yaml — the same field tofu feeds to
                authentik, so there is never a second copy to drift.
              '';
            };

            properties = lib.mkOption {
              type = attrsOf str;
              default = { };
              description = "ZFS properties applied on create and on every run.";
            };
          };
        });
      default = { };
      description = "ZFS datasets to provision on this host, keyed by full dataset path.";
    };
  };

  rbn.system._.hardware._.storage._.zfs._.datasets = {
    nixos =
      {
        config,
        lib,
        pkgs,
        host,
        ...
      }:
      let
        inherit (lib.rbn) get-secret;
        inherit (lib)
          mkIf
          mkMerge
          mapAttrsToList
          concatStringsSep
          concatMap
          optionalString
          escapeShellArg
          unique
          ;

        datasets = host.zfs.datasets;

        # sops-nix addresses nested keys with `/`; users.sops.yaml nests as
        # <key>.attributes.uidNumber.
        uid-key = key: "${key}/attributes/uidNumber";
        acl-keys = unique (concatMap (d: d.acl-users) (builtins.attrValues datasets));

        props = d: d.properties // (if d.quota == null then { } else { inherit (d) quota; });

        set-prop = dataset: name: value: ''
          zfs set ${escapeShellArg "${name}=${value}"} ${dataset}
        '';

        grant = dataset: key: ''
          uid=$(cat ${config.sops.secrets.${uid-key key}.path})
          case "$uid" in
            "" | *[!0-9]*)
              echo "refusing to ACL ${dataset}: uidNumber for ${key} is not numeric" >&2
              exit 1
              ;;
          esac
          # `d:` entries are the defaults new children inherit; g::rwx keeps the
          # owning group writable on files created under a 022 umask.
          setfacl -m "u:$uid:rwx" -m "d:u:$uid:rwx" -m "d:g::rwx" "$mount"
        '';

        provision = name: d: ''
          dataset=${escapeShellArg name}
          # -p so a declared child does not require its parents to be declared
          zfs list -H -o name "$dataset" >/dev/null 2>&1 || zfs create -p "$dataset"

          ${concatStringsSep "" (mapAttrsToList (set-prop "\"$dataset\"") (props d))}
          mount=$(zfs get -H -o value mountpoint "$dataset")

          ${optionalString (d.owner != null) ''chown ${escapeShellArg d.owner} "$mount"''}
          ${optionalString (d.mode != null) ''chmod ${escapeShellArg d.mode} "$mount"''}
          ${concatStringsSep "\n" (map (grant name) d.acl-users)}
        '';
      in
      mkIf (datasets != { }) (mkMerge [
        (mkMerge (map (key: get-secret config (uid-key key) "users") acl-keys))

        {
          systemd.services.zfs-datasets = {
            description = "Provision declared ZFS datasets";
            after = [
              "zfs-import.target"
              "local-fs.target"
            ];
            wants = [ "zfs-import.target" ];
            # nothing may consume a tree before its quota and ACLs are on it
            before = [ "k3s.service" ];
            wantedBy = [ "multi-user.target" ];
            path = with pkgs; [
              zfs
              acl
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              set -euo pipefail

              ${concatStringsSep "\n" (mapAttrsToList provision datasets)}
            '';
          };
        }
      ]);
  };
}
