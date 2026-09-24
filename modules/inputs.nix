{ inputs, lib, ... }:
let
  mk-nixpkgs-alias =
    alias: sources: _final: prev:
    let
      source = if prev.stdenv.hostPlatform.isDarwin then sources.darwin else sources.linux;
    in
    {
      ${alias} = import source {
        inherit (prev.stdenv.hostPlatform) system;
        inherit (prev) config;
      };
    };
in
{
  flake-file.inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = lib.mkForce "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable-linux.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-stable-darwin.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    nix-darwin = {
      url = lib.mkDefault "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    topology.url = "github:oddlama/nix-topology";
    disko.url = "github:nix-community/disko";

    nix-unit = {
      url = "github:nix-community/nix-unit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.overlays.stable = mk-nixpkgs-alias "stable" {
    linux = inputs.nixpkgs-stable-linux;
    darwin = inputs.nixpkgs-stable-darwin;
  };

  den.default.nixos = {
    imports = [
      inputs.topology.nixosModules.default
      inputs.disko.nixosModules.disko
    ];
  };

  den.default.darwin = {
    imports = [
    ];
  };

  # Custom outputs template: same shape as "dendritic" but reads the module
  # tree from ./modules, a root-level tree alongside the repo's other
  # tool-specific trees (kubernetes/, tofu/, mikrotik/, src/homelab).
  flake-file.outputs = ''
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)
  '';
}
