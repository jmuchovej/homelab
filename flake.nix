{
  description = "The Rebellion";

  inputs = {
    catppuccin.url = "github:catppuccin/nix";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # Nix & NixOS
    nix.url = "github:NixOS/nix/2.27-maintenance";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-git.url = "github:NixOS/nixpkgs";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nh.url = "github:nix-community/nh";
    nh.inputs.nixpkgs.follows = "nixpkgs";

    # Nix Darwin
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nix-rosetta-builder.url = "github:cpick/nix-rosetta-builder";
    nix-rosetta-builder.inputs.nixpkgs.follows = "nixpkgs";

    # Bookstrapping NixOS
    ## System images/artifacts builder
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    ## Partition primary root FS
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    ## Configures Cluster Topology
    topology.url = "github:oddlama/nix-topology";
    ## Setup `/` to default to a tmpFS 🙃
    impermanence.url = "github:nix-community/impermanence";

    # Nix User Repository (follows upstream)
    nur.url = "github:nix-community/NUR";

    # Home Manager (follows upstream)
    # home-manager.url = "github:jmuchovej/forked-home-manager/cherry-picks";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    # SOPS (secrets alongside Nix)
    sops-nix.url = "github:Mic92/sops-nix";

    # Deploy
    deploy.url = "github:serokell/deploy-rs";

    # authentik
    authentik-nix.url = "github:nix-community/authentik-nix";

    # homebrew
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-services = {
      url = "github:homebrew/homebrew-services";
      flake = false;
    };
    homebrew-fvm = {
      url = "github:leoafarias/fvm";
      flake = false;
    };

    # MCP Servers
    mcp-servers.url = "github:natsukium/mcp-servers-nix";
  };

  outputs =
    inputs:
    let
      lib = import ./src/lib { inherit inputs; };
    in
    lib.rebellion.mk-flake {
      inherit inputs;
      src = ./.;

      overlays = with inputs; [
        nur.overlays.default
        topology.overlays.default
        nix-vscode-extensions.overlays.default
        mcp-servers.overlays.default
      ];

      modules = with inputs; {
        nixos = [
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          topology.nixosModules.default
          catppuccin.nixosModules.catppuccin
          nix-index-database.nixosModules.nix-index
          authentik-nix.nixosModules.default
        ];
        macos = [
          home-manager.darwinModules.home-manager
          sops-nix.darwinModules.sops
          nix-homebrew.darwinModules.nix-homebrew
        ];
        homes = [
          nix-index-database.homeModules.nix-index
          catppuccin.homeModules.catppuccin
          sops-nix.homeManagerModules.sops
        ];
      };

    };
}
