{ inputs, lib, ... }:
{
  flake-file.inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = lib.mkForce "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    nix-darwin = {
      url = lib.mkDefault "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    topology.url = "github:oddlama/nix-topology";
    disko.url = "github:nix-community/disko";
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
  # tree from ./src/modules so that ./src can host non-module sources too
  # (e.g., ./src/homelab Python CLI, future ./src/terraform, etc.).
  flake-file.outputs = ''
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./src/modules)
  '';
}
