{
  description = "Homelab";

  inputs = {
    # Flake Utils
    flake-utils.url = "github:numtide/flake-utils";

    # Nix & NixOS
    nix.url = "github:NixOS/nix/2.25-maintenance";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs?ref=master";

    # Topology
    topology.url = "github:oddlama/nix-topology";

    # Nix Darwin
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Nix User Repository
    nur.url = "github:nix-community/NUR";

    # Home Manager
    # home-manager.url = "github:nix-community/home-manager?ref=release-24.05";
    # home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # SOPS
    sops-nix.url = "github:Mic92/sops-nix";

    # Deploy
    deploy.url = "github:serokell/deploy-rs";

    # Snowfall
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";
  };

  # outputs = { ... } @ args: import ./flake-outputs.nix args;
  outputs = inputs:
    inputs.snowfall-lib.mkLib {
      inherit inputs;

      channels-config = {
        allowUnfree = true;
      };

      src = ./.;

      snowfall = {
        metadata = "rebellion";
        namespace = "rebellion";

        meta = {
          name  = "rebellion";
          title = "The Rebellion";
        };
      };

      systems.modules = {
        darwin  = with inputs; [ sops-nix.nixosModules.sops ];
        nixos   = with inputs; [ sops-nix.nixosModules.sops ];
      };
    };
}
