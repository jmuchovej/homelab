{ inputs }:
{
  system,
  hostname,
  username ? "john",
  modules ? [ ],
  ...
}:
let
  flake = inputs.self or (throw "mk-nixos requires 'inputs.self' to be passed");
  common = import ./common.nix { inherit inputs; };

  ext-lib = common.mk-ext-lib flake inputs.nixpkgs;
  matching-homes = common.gather-homes {
    inherit
      flake
      system
      hostname
      ;
  };
  hm-config = common.mk-hm-config {
    inherit
      ext-lib
      inputs
      flake
      system
      matching-homes
      ;
    isNixOS = true;
  };

  nixpkgs-config = common.mk-nixpkgs-config flake;
in
inputs.nixpkgs.lib.nixosSystem {
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
  ++ flake.rebellion.modules.nixos
  # Auto-inject home configurations for this system+hostname
  ++ [ hm-config ]
  # Import all nixos modules recursively
  ++ (ext-lib.import-modules-recursive ../../modules/nixos { })
  ++ [ ../../systems/${system}/${hostname} ]
  ++ modules;
}
