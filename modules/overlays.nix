# Overlay management.
#
# Discovers overlays from modules/_overlays/*.nix using import-tree.
{ inputs, lib, ... }:
let
  inherit (inputs) import-tree;

  # Discover overlay files from _overlays/
  # import-tree skips _-prefixed dirs, so _packages/ is excluded.
  # .map import gives raw file contents (overlay functions or { inputs }: overlay).
  # .leaves returns a flat list.
  raw-overlays = lib.pipe import-tree [
    (i: i.map import)
    (i: i.withLib lib)
    (i: i.leaves ./_overlays)
  ];

  # Each overlay file is either a function { inputs }: overlay or a raw overlay.
  discovered-overlays = map (f: if lib.isFunction f then f { inherit inputs; } else f) raw-overlays;
in
{
  den.default = {
    nixos.nixpkgs.overlays = discovered-overlays;
    darwin.nixpkgs.overlays = discovered-overlays;
  };

  flake.overlays = {
    rbn = import ./_overlays/rbn.nix { inherit inputs; };
  };
}
