{
  description = "The Rebellion";

  inputs = {
    catppuccin.url = "github:catppuccin/nix";

    # Flake Utils
    flake-utils.url = "github:numtide/flake-utils";

    # Nix & NixOS
    nix.url = "github:NixOS/nix/2.27-maintenance";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-git.url = "github:NixOS/nixpkgs";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/release-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nh
    nh.url = "github:nix-community/nh";
    nh.inputs.nixpkgs.follows = "nixpkgs";

    # Nix Darwin
    darwin.url = "github:nix-darwin/nix-darwin";
    # darwin.url = "github:jmuchovej/forked-nix-darwin/cherry-picks";
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";
    # Install Mac Apps in a Spotlight-discoverable way.
    # mac-app-util.url = "github:hraban/mac-app-util";
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

    # Snowfall
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";
    snowfall-flake.url = "github:snowfallorg/flake";
    snowfall-flake.inputs.nixpkgs.follows = "nixpkgs";

    # treefmt
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # git-hooks
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

    # authentik
    authentik-nix.url = "github:nix-community/authentik-nix";

    # homebrew
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Optional: Declarative tap management
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
  };

  # outputs = { ... } @ args: import ./flake-outputs.nix args;
  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          # metadata = "rebellion";
          namespace = "rebellion";

          meta = {
            name = "rebellion";
            title = "The Rebellion";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
        nur.overlays.default
        topology.overlays.default
        nix-vscode-extensions.overlays.default
      ];

      homes.modules = with inputs; [
        # mac-app-util.homeManagerModules.default
        sops-nix.homeManagerModules.sops
        catppuccin.homeModules.catppuccin
      ];

      systems.modules = {
        darwin = with inputs; [
          # { nix.linux-builder.enable = true; }
          # nix-rosetta-builder.darwinModules.default
          # mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          sops-nix.darwinModules.sops
          nix-homebrew.darwinModules.nix-homebrew
        ];
        nixos = with inputs; [
          disko.nixosModules.disko
          # This is needed for `impermanence` to work.
          # { fileSystems."/persist".neededForBoot = true; }
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          topology.nixosModules.default
          authentik-nix.nixosModules.default
        ];

        outputs-builder = channels: {
          formatter = inputs.treefmt-nix.lib.mkWrapper channels.nixpkgs ./treefmt.nix;
        };
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
