{
  inputs,
  __findFile,
  lib,
  ...
}:
let
  # Build the extended lib with lib.rebellion.* functions
  rebellion-lib = import ../src/lib { inherit inputs; };
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
  };

  # Override instantiate to inject rebellion-lib and specialArgs into OS evaluation.
  den.schema.host =
    { config, ... }:
    let
      # Parse datacenter/nodename from host name (e.g., "da-vcx-1" -> datacenter="da", nodename="vcx-1")
      parts = lib.splitString "-" config.name;
      datacenter = builtins.elemAt parts 0;
      nodename = lib.concatStringsSep "-" (lib.drop 1 parts);
      hostname = config.name;

      hostSpecialArgs = {
        host = config;
        inherit datacenter nodename hostname;
        inherit (config) system;
        peers = [ ]; # TODO: compute from all den hosts in same datacenter
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
