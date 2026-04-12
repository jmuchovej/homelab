{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nixpkgs.url = lib.mkForce "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-file.url = lib.mkForce "github:vic/flake-file/v0.5.0";
    flake-parts.url = "github:hercules-ci/flake-parts";
    den.url = lib.mkForce "github:vic/den/v0.12.0";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    nix-darwin = {
      url = lib.mkDefault "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    topology.url = "github:oddlama/nix-topology";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
  };

  den.default.nixos = {
    imports = [
      inputs.topology.nixosModules.default
      inputs.disko.nixosModules.disko
    ];
  };

  def.default.darwin = {
    imports = [
      inputs.nix-darwin.nixosModules.darwin
    ];
  };

  imports = [
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.flakeModules.dendritic or { })
  ];

  flake-file.outputs = "dendritic";
}
