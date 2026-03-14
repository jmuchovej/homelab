{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nixpkgs.url = lib.mkForce "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-file.url = lib.mkForce "github:vic/flake-file/v0.5.0";
    flake-parts.url = "github:hercules-ci/flake-parts";
    den.url = lib.mkForce "github:vic/den/v0.12.0";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    mcp-servers-nix.url = "github:natsukium/mcp-servers-nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
  };

  imports = [
    (inputs.flake-file.flakeModules.dendritic or { })
    (inputs.den.flakeModules.dendritic or { })
  ];

  flake-file.outputs = "dendritic";
}
