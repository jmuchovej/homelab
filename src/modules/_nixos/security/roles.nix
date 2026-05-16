{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "security.roles";
  # Option definitions kept — rebellion.security.roles.{definitions,user-roles}
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
              };
              capabilities = mkOption {
                type = types.listOf types.str;
                default = [ ];
              };
            };
          }
        );
        default = {
          operator.groups = [ "wheel" ];
          developer.groups = [
            "docker"
            "libvirtd"
          ];
          cluster-admin.groups = [ "k3s" ];
        };
      };
      user-roles = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
      };
    };
  # Config extracted — role-to-group mapping applied via users.users
  config =
    { cfg, lib, ... }:
    {
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
