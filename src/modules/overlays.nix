# Overlay management.
#
# Discovers overlays from modules/_overlays/*.nix using import-tree.
# Creates pkgs.contrib.* namespace from modules/_overlays/_packages/contrib/
# for upstream-bound packages (nixpkgs-compatible, no den/rebellion dependencies).
{ inputs, lib, ... }:
let
  inherit (builtins) pathExists;
  inherit (inputs) import-tree;

  # Discover overlay files from _overlays/
  # import-tree skips _-prefixed dirs, so _packages/ is excluded.
  # .map import gives raw file contents (overlay functions or { inputs }: overlay).
  # .leafs returns a flat list.
  raw-overlays = lib.pipe import-tree [
    (i: i.map import)
    (i: i.withLib lib)
    (i: i.leafs ./_overlays)
  ];

  # Each overlay file is either a function { inputs }: overlay or a raw overlay.
  discovered-overlays = map (f: if lib.isFunction f then f { inherit inputs; } else f) raw-overlays;

  # packages-contrib overlay: creates pkgs.contrib.*
  contrib-dir = ./_overlays/_packages/contrib;
  contrib-overlays =
    if pathExists contrib-dir then
      final: _prev: {
        contrib = _prev.lib.filesystem.packagesFromDirectoryRecursive {
          directory = contrib-dir;
          inherit (final) callPackage;
        };
      }
    else
      _final: _prev: { };

  all-overlays = discovered-overlays ++ [ contrib-overlays ];
in
{
  den.default = {
    nixos.nixpkgs.overlays = all-overlays;
    darwin.nixpkgs.overlays = all-overlays;
  };

  flake.overlays = {
    contrib = contrib-overlays;
  };
}
