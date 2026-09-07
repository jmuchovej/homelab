# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs =
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./src/modules);

  inputs = {
    anthropic-skills = {
      url = "github:anthropics/skills/1ed29a03dc852d30fa6ef2ca53a67dc2c2c2c563";
      flake = false;
    };
    den.url = "github:denful/den";
    deploy.url = "github:serokell/deploy-rs";
    devenv.url = "github:cachix/devenv/v2.3.1";
    disko.url = "github:nix-community/disko";
    flake-file.url = "github:denful/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-services = {
      url = "github:homebrew/homebrew-services";
      flake = false;
    };
    impermanence.url = "github:nix-community/impermanence";
    import-tree.url = "github:denful/import-tree";
    lanzaboote.url = "github:nix-community/lanzaboote";
    llm-agents.url = "github:numtide/llm-agents.nix";
    mac-keycodes = {
      url = "file+https://gist.githubusercontent.com/eegrok/949034/raw/af13a5ec66ff5eb6fd15f28eea560554e31416a3/mac-keycodes";
      flake = false;
    };
    mcp-servers.url = "github:natsukium/mcp-servers-nix";
    nh.url = "github:nix-community/nh";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-unit = {
      url = "github:nix-community/nix-unit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixvirt.url = "github:AshleyYakeley/NixVirt";
    oh-my-tmux = {
      url = "github:gpakosz/.tmux";
      flake = false;
    };
    sops-nix.url = "github:mic92/sops-nix";
    topology.url = "github:oddlama/nix-topology";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };
}
