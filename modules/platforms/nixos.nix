{ inputs, lib, ... }:
{
  flake-file.inputs.topology.url = "github:oddlama/nix-topology";
  flake-file.inputs.disko.url = "github:nix-community/disko";
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  den.default.nixos = {
    imports = [
      inputs.topology.nixosModules.default
      inputs.disko.nixosModules.disko
    ];
  };
}
