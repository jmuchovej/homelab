{ inputs, ... }:
{
  imports = [
    ../lib
    ./overlays.nix
    ./packages.nix
    ./modules.nix
    ./systems.nix
    ./homes.nix
    inputs.flake-parts.flakeModules.partitions
  ];

  # partitions.dev = {
  #   module = ./dev;
  #   extraInputsFlake = ./dev;
  # };

  # partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
  #   "checks"
  #   "devShells"
  #   "formatter"
  #   "templates"
  # ] (_: "dev");
}
