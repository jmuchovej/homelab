{ inputs, ... }:
{
  imports = [
    ../lib
    ./overlays.nix
    ./packages.nix
    ./modules.nix
    ./systems.nix
    ./deploy.nix
    ./homes.nix
    inputs.flake-parts.flakeModules.partitions
  ];

  partitions.dev = {
    module = ./dev/dev.nix;
    extraInputsFlake = ./dev;
  };

  partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
    "checks"
    "devShells"
    "formatter"
  ] (_: "dev");
}
