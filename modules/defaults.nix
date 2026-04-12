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

    nixos.nixpkgs.overlays = overlay-config.all-overlays;
    darwin.nixpkgs.overlays = overlay-config.all-overlays;
  };

  # Override instantiate to inject rebellion-lib and specialArgs into OS evaluation.
  den.schema.host =
    { config, ... }:
    let
      hostSpecialArgs = {
        host = config;
        inherit (config) system; # required by nixpkgs for hostPlatform resolution
        inherit (inputs) self;
        inputs = rebellion-lib.rebellion.flake.without-src inputs;
      };

      nixosSpecialArgs = hostSpecialArgs // {
        format = "linux";
      };

      darwinSpecialArgs = hostSpecialArgs // {
        format = "darwin";
      };

    in
    lib.mkMerge [
      (lib.mkIf (config.class == "nixos") {
        instantiate = lib.mkForce (
          args:
          inputs.nixpkgs.lib.nixosSystem (
            args
            // {
              lib = rebellion-lib;
              modules = args.modules or [ ];
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
              modules = args.modules or [ ];
              specialArgs = (args.specialArgs or { }) // darwinSpecialArgs;
            }
          )
        );
      })
    ];
}
