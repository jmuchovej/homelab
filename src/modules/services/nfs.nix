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
      };
    };

  rbn.services._.nfs = {
    nixos =
      { host, lib, ... }:
      {
        services.nfs.server = {
          enable = true;
          exports =
            (lib.concatMapStringsSep "\n" (e: "${e.path} ${e.clients}(${e.options})") host.nfs.exports) + "\n";
        };
        networking.firewall.allowedTCPPorts = [ 2049 ];
      };
  };
}
