{ inputs, lib, ... }:
{
  flake-file.inputs = {
    authentik-nix.url = "github:nix-community/authentik-nix";
  };

  rbn.aspects.authentik.nixos = {
    imports = [
      inputs.authentik-nix.nixosModules.default
    ];
  };
}
