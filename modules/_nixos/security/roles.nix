{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "security.roles";
  description = "RBAC";
  options =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
    in
    {
      definitions = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              groups = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Groups associated with this role";
              };
              capabilities = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Capabilities granted by this role";
              };
            };
          }
        );
        default = {
          operator = {
            groups = [ "wheel" ];
            capabilities = [ "system-management" ];
          };
          developer = {
            groups = [
              "docker"
              "libvirtd"
            ];
            capabilities = [ "container-management" ];
          };
          cluster-admin = {
            groups = [ "k3s" ];
            capabilities = [ "cluster-management" ];
          };
        };
      };

      user-roles = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Map users to roles";
      };
    };
  config =
    { cfg, lib, ... }:
    {
      # Apply roles to users without exposing what services exist
      users.users = lib.mapAttrs (
        _userName: roles:
        let
          userGroups = lib.flatten (map (role: cfg.definitions.${role}.groups or [ ]) roles);
        in
        {
          extraGroups = userGroups;
        }
      ) cfg.user-roles;
    };
}
