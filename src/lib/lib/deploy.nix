## Deploy node generation for deploy-rs.
##
## Generates deploy.nodes from nixosConfigurations.
{
  lib,
  inputs,
  ...
}:
let
  inherit (lib) assertMsg;
  deploy-lib = inputs.deploy.lib;
in
assert (
  assertMsg (inputs ? deploy) "Need `deploy-rs` aliased as `deploy` to apply remote configurations"
);
{
  deploy = {
    ## Generate deploy-rs nodes from nixosConfigurations.
    ## Each node gets SSH config and a system activation profile.
    #@ Attrs -> Attrs
    mk-deploy-nodes =
      nixosConfigurations:
      builtins.mapAttrs (
        hostname: nixosCfg:
        let
          inherit (nixosCfg.pkgs.stdenv.hostPlatform) system;
        in
        {
          inherit hostname;
          sshUser = "lab";
          user = "root";
          magicRollback = true;
          autoRollback = true;
          remoteBuild = true;
          profiles.system = {
            path = deploy-lib.${system}.activate.nixos nixosCfg;
          };
        }
      ) nixosConfigurations;
  };
}
