{
  inputs,
  __findFile,
  lib,
  ...
}:
let
  # Build the extended lib with lib.rebellion.* functions
  rebellion-lib = import ../src/lib { inherit inputs; };

  # Build overlays (pkgs.rebellion.* + overlays/ directory)
  overlay-config = rebellion-lib.rebellion.overlay.mk-overlays {
    paths = {
      packages = ../packages;
      overlays = ../overlays;
    };
  };

  # Discover .nix modules in a directory (excludes .part.nix files)
  discoverModules =
    dir:
    builtins.filter (
      f:
      let
        s = toString f;
      in
      lib.hasSuffix ".nix" s && !(lib.hasSuffix ".part.nix" s)
    ) (lib.filesystem.listFilesRecursive dir);

  # External flake NixOS/Darwin/HM modules
  externalNixosModules = [
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.authentik-nix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];

  externalDarwinModules = [
    inputs.sops-nix.darwinModules.sops
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  externalHmModules = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.mcp-servers-nix.homeManagerModules.default
  ];

  # Pre-compute underscore module lists
  nixosModules = externalNixosModules ++ discoverModules ./_nixos ++ discoverModules ./_common;
  darwinModules = externalDarwinModules ++ discoverModules ./_macos ++ discoverModules ./_common;
  hmModules = externalHmModules ++ discoverModules ./_home;
in
{
  den.default = {
    includes = [
      <den/define-user>
      (
        { host, ... }:
        {
          ${host.class}.networking.hostName = host.name;
        }
      )
    ];

    nixos = {
      nixpkgs.overlays = overlay-config.all-overlays;
      home-manager.sharedModules = hmModules;
    };
    darwin = {
      nixpkgs.overlays = overlay-config.all-overlays;
      home-manager.sharedModules = hmModules;
    };

    homeManager =
      { config, lib, ... }:
      {
        programs.home-manager.enable = true;
        home.sessionPath = [ "$HOME/.local/bin" ];
        home.stateVersion = lib.mkDefault "25.11";
        rebellion.user.name = lib.mkDefault config.home.username;
      };
  };

  # Override instantiate to inject rebellion-lib, underscore modules,
  # and specialArgs (datacenter, nodename, etc.) into OS evaluation.
  den.schema.host =
    { config, ... }:
    let
      # Parse datacenter/nodename from host name (e.g., "da-vcx-1" -> datacenter="da", nodename="vcx-1")
      parts = lib.splitString "-" config.name;
      datacenter = builtins.elemAt parts 0;
      nodename = lib.concatStringsSep "-" (lib.drop 1 parts);
      hostname = config.name;

      hostSpecialArgs = {
        inherit datacenter nodename hostname;
        host = hostname; # alias used by some modules (e.g., syncthing)
        inherit (config) system; # architecture (e.g., x86_64-linux)
        peers = [ ]; # TODO: compute from all den hosts
        inherit (inputs) self;
        inputs = rebellion-lib.rebellion.flake.without-src inputs;
      };

      nixosSpecialArgs = hostSpecialArgs // {
        format = "linux";
      };

      darwinSpecialArgs = hostSpecialArgs // {
        format = "darwin";
      };

      # System file: systems/{arch}/{nodename}@{datacenter}.nix
      # e.g., "da-vcx-1" on x86_64-linux → ../systems/x86_64-linux/vcx-1@da.nix
      systemFile = ../systems + "/${config.system}/${nodename}@${datacenter}.nix";

      # Per-user home config imports from homes/{system}/{user}[@{nodename}].nix
      userHomeImports = lib.mapAttrs (
        username: _:
        let
          hostFile = ../homes + "/${config.system}/${username}@${nodename}.nix";
          genericFile = ../homes + "/${config.system}/${username}.nix";
        in
        {
          imports =
            lib.optional (builtins.pathExists hostFile) hostFile
            ++ lib.optional (builtins.pathExists genericFile) genericFile;
        }
      ) (config.users or { });
    in
    lib.mkMerge [
      (lib.mkIf (config.class == "nixos") {
        instantiate = lib.mkForce (
          args:
          inputs.nixpkgs.lib.nixosSystem (
            args
            // {
              lib = rebellion-lib;
              modules =
                (args.modules or [ ])
                ++ nixosModules
                ++ [
                  systemFile
                  {
                    home-manager.extraSpecialArgs = nixosSpecialArgs;
                    home-manager.users = userHomeImports;
                  }
                ];
              specialArgs = (args.specialArgs or { }) // nixosSpecialArgs;
            }
          )
        );
      })
      (lib.mkIf (config.class == "darwin") {
        instantiate = lib.mkForce (
          args:
          inputs.nix-darwin.lib.darwinSystem (
            args
            // {
              lib = rebellion-lib;
              modules =
                (args.modules or [ ])
                ++ darwinModules
                ++ [
                  systemFile
                  {
                    home-manager.extraSpecialArgs = darwinSpecialArgs;
                    home-manager.users = userHomeImports;
                  }
                ];
              specialArgs = (args.specialArgs or { }) // darwinSpecialArgs;
            }
          )
        );
      })
    ];
}
