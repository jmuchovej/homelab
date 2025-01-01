{
  description = "Homelab";

  inputs = {
    # Flake Utils
    flake-utils.url = "github:numtide/flake-utils";

    # Nix & NixOS
    nix.url = "github:NixOS/nix/2.25-maintenance";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Topology
    topology.url = "github:oddlama/nix-topology";

    # Nix Darwin
    # darwin.url = "github:LnL7/nix-darwin";
    darwin.url = "github:khaneliman/nix-darwin/cherry-picks";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Install Mac Apps in a Spotlight-discovery way.
    mac-app-util.url = "github:hraban/mac-app-util";

    # System images/artifacts builder
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository
    nur.url = "github:nix-community/NUR";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # SOPS
    sops-nix.url = "github:Mic92/sops-nix";

    # Deploy
    deploy.url = "github:serokell/deploy-rs";

    # Snowfall
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";
  };

  # outputs = { ... } @ args: import ./flake-outputs.nix args;
  outputs = inputs: let
    lib = inputs.snowfall-lib.mkLib {
      inherit inputs;
      src = ./.;

      snowfall = {
        # metadata = "rebellion";
        namespace = "rebellion";

        meta = {
          name  = "rebellion";
          title = "The Rebellion";
        };
      };
    };
  in lib.mkFlake {
      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
        nur.overlays.default
        topology.overlays.default
      ];

      homes.modules = with inputs; [
        mac-app-util.homeManagerModules.default
        sops-nix.homeManagerModules.sops
      ];

      systems.modules = {
        darwin  = with inputs; [
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          sops-nix.darwinModules.sops
        ];
        nixos   = with inputs; [
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          topology.nixosModules.default
        ];
      };

      # topology = with inputs; let
      #   node-name = builtins.head (builtins.attrNames self.nixosConfigurations);
      #   host = self.nixosConfigurations.${node-name};
      # in import topology {
      #   inherit (host) pkgs;
      #   modules = [
      #     (import ./topology { inherit (host) config; })
      #     { inherit (self) nixosConfigurations; }
      #   ];
      # };
    };
}
