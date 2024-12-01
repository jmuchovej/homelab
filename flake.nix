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

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager?ref=release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SOPS
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deploy
    deploy.url = "github:serokell/deploy-rs";
  };

  # outputs = { ... } @ args: import ./flake-outputs.nix args;
  outputs = {
    self, nixpkgs, home-manager, sops-nix, deploy, ...
  } @ inputs :
  let
    inherit (self) outputs;
    forAllSystems = nixpkgs.lib.genAttrs [
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-linux"
    ];

    secrets = import ./secrets;

    mkNixos =
      modules:
      nixpkgs.lib.nixosSystem {
        modules = modules ++ [ sops-nix.nixosModules.sops ];
        specialArgs = {
          inherit inputs outputs secrets;
        };
      };

    # mkDarwin =
    #   system: modules:
    #   darwin.lib.darwinSystem {
    #     inherit modules;
    #     system = system;
    #     specialArgs = {
    #       inherit inputs outputs secrets;
    #     };
    #   };

    mkHome =
      pkgs: modules:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs modules;
        extraSpecialArgs = {
          inherit inputs outputs secrets;
        };
      };
  in rec {
    packages = forAllSystems (
      system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          customPkgs = import ./custom/pkgs { inherit pkgs; };
          devcontainer = pkgs.dockerTools.buildImage {
            name  = "devcontainer";
            tag   = "latest";
            contents = import ./devcontainer.nix {
              inherit pkgs;
            };
            config.Cmd = [ "/bin/zsh"];
          };
        }
    );

    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (
      system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style
    );

    # Devshell for bootstrapping
    # Acessible through 'nix develop' or 'nix-shell' (legacy)
    devShells = forAllSystems (
      system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix {
          inherit pkgs;
          inherit (sops-nix.packages.${system}) sops-import-keys-hook sops-init-gpg-key;
          inherit (deploy.packages.${system}) deploy-rs;
        }
    );

    # Overlays
    overlays = import ./custom/overlays {
      inherit inputs;
    };

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild switch --flake .#your-hostname'
    nixosConfigurations = {
      # Servers: hvn1
      # s1-red1 = mkNixos [ ./hosts/s1-red1 ];
      # s1-red2 = mkNixos [ ./hosts/s1-red3 ];
      # s1-red3 = mkNixos [ ./hosts/s1-red3 ];

      # Servers: tlh1
      red1-s2 = mkNixos [ ./hosts/alderaan-red1 ];
    };

    # nix-darwin configuration entrypoint
    # Available through 'darwin-rebuild switch --flake .#your-hostname'
    # darwinConfigurations = {
    #   "${secrets.hosts.work-mac.hostname}" = mkDarwin "aarch64-darwin" [ ./hosts/darwin ];
    # };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager switch --flake .#your-username@your-hostname'
    # homeConfigurations = {
    #   "${secrets.hosts.work-mac.username}@${secrets.hosts.work-mac.hostname}" =
    #       mkHome nixpkgs.legacyPackages.aarch64-darwin
    #         [ ./home-manager/darwin ];
    # };
  };
}
