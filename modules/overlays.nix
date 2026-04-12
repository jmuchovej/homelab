# Overlay management.
#
# Discovers overlays from modules/_overlays/*.nix using import-tree.
# Creates pkgs.contrib.* namespace from modules/_overlays/_packages/contrib/
# for upstream-bound packages (nixpkgs-compatible, no den/rebellion dependencies).
{ inputs, lib, ... }:
let
  inherit (builtins) pathExists;
  import-tree = inputs.import-tree;

  # Discover overlay files from _overlays/
  # import-tree skips _-prefixed dirs, so _packages/ is excluded.
  # .map import gives raw file contents (overlay functions or { inputs }: overlay).
  # .leafs returns a flat list.
  rawOverlays = lib.pipe import-tree [
    (i: i.map import)
    (i: i.withLib lib)
    (i: i.leafs ./_overlays)
  ];

  # Each overlay file is either a function { inputs }: overlay or a raw overlay.
  discoveredOverlays = map (
    f: if lib.isFunction f then f { inherit inputs; } else f
  ) rawOverlays;

  # packages-contrib overlay: creates pkgs.contrib.*
  contribDir = ./_overlays/_packages/contrib;
  contribOverlay =
    if pathExists contribDir then
      final: _prev: {
        contrib = _prev.lib.filesystem.packagesFromDirectoryRecursive {
          directory = contribDir;
          callPackage = final.callPackage;
        };
      }
    else
      _final: _prev: { };

  allOverlays = discoveredOverlays ++ [ contribOverlay ];
in
{
  den.default = {
    nixos.nixpkgs.overlays = allOverlays;
    darwin.nixpkgs.overlays = allOverlays;
  };

  flake.overlays = {
    contrib = contribOverlay;
  };
}
