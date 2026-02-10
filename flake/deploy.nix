{ inputs, self, ... }:
let
  inherit (self.lib.file) parse-system-configurations filter-nixos-systems;
  deployLib = inputs.deploy.lib;
  systems = filter-nixos-systems (parse-system-configurations ../systems);
in
{
  flake.deploy.nodes = builtins.mapAttrs (
    _:
    { system, hostname, ... }:
    {
      inherit hostname;
      sshUser = "lab";
      user = "root";
      magicRollback = true;
      autoRollback = true;
      remoteBuild = true;
      profiles.system = {
        path = deployLib.${system}.activate.nixos self.nixosConfigurations.${hostname};
      };
    }
  ) systems;
}
