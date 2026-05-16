# Shared host schema options — available to all hosts via `host.*`.
# Individual service schemas are colocated in their aspect files.
# This file defines cross-cutting options used by many aspects.
{ lib, den, ... }:
{
  den.schema.host =
    { config, lib, ... }:
    let
      inherit (lib) mkOption mkEnableOption;
      inherit (lib.types)
        str
        int
        nullOr
        listOf
        attrs
        bool
        ;

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
          description = "Full hostname (same as host name)";
        };
        # ── Primary user ───────────────────────────────────────────────
        # Named `primary-user` rather than `user` to avoid colliding with
        # den's fx-pipeline `user` context binding (host.user is implicitly
        # passed as the `user` arg to user-scoped parametric aspects).
        primary-user = {
          name = mkOption {
            type = str;
            default = "lab";
            description = "Primary user account name";
          };
          full-name = mkOption {
            type = str;
            default = "lab";
            description = "User's full name";
          };
          email = mkOption {
            type = str;
            default = "homelab@jm0.io";
            description = "User's email";
          };
          uid = mkOption {
            type = nullOr int;
            default = null;
            description = "User UID (null = auto)";
          };
          extra = {
            groups = mkOption {
              type = listOf str;
              default = [ ];
              description = "Extra groups to assign";
            };
            options = mkOption {
              type = attrs;
              default = { };
              description = "Extra options for users.users.<name>";
            };
          };
        };

        # ── Cross-service flags ────────────────────────────────────────
        sops.enable = mkOption {
          type = bool;
          default = true;
          description = "Whether sops secrets management is enabled";
        };
        tailscale.enable = mkEnableOption "Tailscale VPN";
        containers.enable = mkEnableOption "Container runtime (Podman/Docker)";

        # ── Homebrew (darwin) ──────────────────────────────────────────
        homebrew = {
          enable = mkOption {
            type = bool;
            default = false;
            description = "Enable Homebrew";
          };
          mas.enable = mkOption {
            type = bool;
            default = false;
            description = "Enable Mac App Store downloads";
          };
        };
      };
    };
}
