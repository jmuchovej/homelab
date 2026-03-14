{ inputs, lib, ... }:
{
  flake-file.inputs.nix-darwin = {
    url = lib.mkDefault "github:nix-darwin/nix-darwin";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
