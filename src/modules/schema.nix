# Shared host schema options — available to all hosts via `host.*`.
# Individual service schemas are colocated in their aspect files.
# This file defines cross-cutting options used by many aspects.
{
  den.schema.host =
    { config, lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) str;

      # Derive datacenter/nodename/hostname from host name
      # e.g., "da-vcx-1" → datacenter="da", nodename="vcx-1", hostname="da-vcx-1"
      parts = lib.splitString "-" config.name;
    in
    {
      options = {
        # ── Computed from host name ────────────────────────────────────
        datacenter = mkOption {
          type = str;
          default = builtins.elemAt parts 0;
          description = "Datacenter prefix (derived from host name)";
        };
        nodename = mkOption {
          type = str;
          default = lib.concatStringsSep "-" (lib.drop 1 parts);
          description = "Node name without datacenter prefix";
        };
        hostname = mkOption {
          type = str;
          default = config.name;
          description = "Full hostname (same as host.name)";
        };
        # ── Cluster domain (plaintext; not secret — access control, not
        #    obscurity, is the boundary) ─────────────────────────────────
        domain = mkOption {
          type = str;
          default = "jm0.io";
          description = "Base/apex domain for this host's cluster";
        };
        dc-domain = mkOption {
          type = str;
          default = "${config.datacenter}.${config.domain}";
          description = "Per-datacenter subdomain (derived: <datacenter>.<domain>)";
        };
      };
    };
}
