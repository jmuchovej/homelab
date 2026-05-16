{
  inputs,
  lib,
  den,
  ...
}:
let
  # Auto-discovered helper modules from ./_lib/*.nix.
  # The `_`-prefixed dir is skipped by import-tree's auto-discovery at the
  # flake level; we invoke import-tree explicitly on that path here. Each
  # helper file is a function taking `{ lib, inputs }` and returning
  # `{ _rbn-lib = { ... }; }`; contributions merge into `lib.rbn` by
  # extending nixpkgs.lib. Lib extension propagates everywhere nixosSystem's
  # `lib` arg reaches — including den aspect inner functions — which the
  # specialArgs/`_module.args` route does not.
  helpers = lib.pipe inputs.import-tree [
    (i: i.map (path: (import path) { inherit lib inputs; }))
    (i: i.withLib lib)
    (i: i.leafs ./_lib)
  ];
  rbn-lib = lib.foldl' (acc: h: acc // (h._rbn-lib or { })) { } helpers;
  extended-lib = lib.extend (_: _: { rbn = rbn-lib; });
in
{
  den.default.includes = [
    den.batteries.define-user
    den.batteries.hostname
    (
      { host, ... }:
      {
        ${host.class}.networking.hostName = host.name;
      }
    )
  ];

  # Override instantiate to inject our extended lib (with `lib.rbn`) and
  # other host-derived args into OS evaluation.
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
        inputs = removeAttrs inputs [ "src" ];
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
              lib = extended-lib;
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
              lib = extended-lib;
              modules = args.modules or [ ];
              specialArgs = (args.specialArgs or { }) // darwinSpecialArgs;
            }
          )
        );
      })
    ];
}
