# Overlay wiring.
#
# Every overlay is declared as `flake.overlays.<name>`: beside the flake input
# it comes from, or as a file under _overlays/, which this module declares by
# basename. The merged set is applied here and nowhere else.
{
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (inputs) import-tree;

  # Each _overlays/*.nix is `{ inputs }: final: prev: { … }`.
  discovered = lib.pipe import-tree [
    (
      i:
      i.map (
        path:
        lib.nameValuePair (lib.removeSuffix ".nix" (baseNameOf path)) (import path { inherit inputs; })
      )
    )
    (i: i.leaves ./_overlays)
    lib.listToAttrs
  ];

  overlays = lib.attrValues config.flake.overlays;
in
{
  flake.overlays = discovered;

  den.default = {
    nixos.nixpkgs.overlays = overlays;
    darwin.nixpkgs.overlays = overlays;
    # Standalone homes re-import nixpkgs from `pkgs.path` with their own
    # `nixpkgs.overlays`; under `useGlobalPkgs` that option is a stub whose
    # mere definition warns. `nixpkgs.system` exists only in the live module.
    hm =
      { options, ... }:
      {
        nixpkgs.overlays = lib.mkIf (options.nixpkgs ? system) overlays;
      };
  };
}
