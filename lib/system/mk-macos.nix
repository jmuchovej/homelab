{ inputs }:
{
  system,
  hostname,
  username ? "john",
  modules ? [ ],
  ...
}:
let
  flake = inputs.self or (throw "mk-macos requires 'inputs.self' to be passed");
  common = import ./common.nix { inherit inputs; };

  ext-lib = common.mk-ext-lib flake inputs.nixpkgs-unstable;
  matching-homes = common.gather-homes {
    inherit
      flake
      system
      hostname
      ;
  };

  hm-config = common.mk-hm-config {
    inherit
      flake
      ext-lib
      inputs
      system
      matching-homes
      ;
    isNixOS = false;
  };

  nixpkgs-config = common.mk-nixpkgs-config flake;
in
inputs.nix-darwin.lib.darwinSystem {
  inherit system;

  specialArgs = common.mk-special-args {
    inherit
      inputs
      hostname
      username
      ext-lib
      system
      ;
  };

  modules = [
    { _module.args.lib = ext-lib; }

    # Configure nixpkgs with overlays
    {
      nixpkgs = nixpkgs-config;
    }
  ]
  ++ flake.rebellion.modules.macos
  # Auto-inject home configurations for this system+hostname
  ++ [ hm-config ]
  # Import all macos modules recursively
  ++ (ext-lib.import-modules-recursive ../../modules/macos { })
  ++ [ ../../systems/${system}/${hostname} ]
  ++ modules;
}
