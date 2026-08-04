{
  inputs,
  self,
  lib,
  ...
}:
{
  flake-file.inputs.deploy.url = "github:serokell/deploy-rs";

  flake.deploy.nodes = lib.mapAttrs (
    hostname: cfg:
    let
      inherit (cfg.pkgs.stdenv.hostPlatform) system;
    in
    {
      inherit hostname;
      sshUser = "lab";
      user = "root";
      magicRollback = true;
      autoRollback = true;
      remoteBuild = true;
      profiles.system.path = inputs.deploy.lib.${system}.activate.nixos cfg;
    }
  ) (self.nixosConfigurations or { });
}
