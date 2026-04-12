# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    authentik-nix.url = "github:nix-community/authentik-nix";
    den.url = "github:vic/den/v0.16.0";
    deploy.url = "github:serokell/deploy-rs";
    disko.url = "github:nix-community/disko";
    flake-file.url = "github:vic/flake-file/v0.5.0";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    homebrew-cask = {
      flake = false;
      url = "github:homebrew/homebrew-cask";
    };
    homebrew-core = {
      flake = false;
      url = "github:homebrew/homebrew-core";
    };
    homebrew-fvm = {
      flake = false;
      url = "github:leoafarias/fvm";
    };
    homebrew-services = {
      flake = false;
      url = "github:homebrew/homebrew-services";
    };
    impermanence.url = "github:nix-community/impermanence";
    import-tree.url = "github:vic/import-tree";
    lanzaboote.url = "github:nix-community/lanzaboote";
    llm-agents.url = "github:numtide/llm-agents.nix";
    mcp-servers.url = "github:natsukium/mcp-servers-nix";
    nh.url = "github:nix-community/nh";
    nix-darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-darwin/nix-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-lib.follows = "nixpkgs";
    sops-nix.url = "github:mic92/sops-nix";
    topology.url = "github:oddlama/nix-topology";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

}
