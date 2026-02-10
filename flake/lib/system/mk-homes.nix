{ inputs }:
{
  system,
  hostname,
  username ? "john",
  modules ? [ ],
  ...
}:
let
  flake = inputs.self or (throw "mk-home requires 'inputs.self' to be passed");
  common = import ./common.nix { inherit inputs; };

  ext-lib = common.mk-ext-lib flake inputs.nixpkgs-unstable;
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs-unstable {
    inherit system;
    inherit ((common.mk-nixpkgs-config flake)) config overlays;
  };

  extraSpecialArgs = {
    inherit
      inputs
      hostname
      username
      system
      ;
    inherit (flake) self;
    lib = ext-lib;
    flake-parts-lib = inputs.flake-parts.lib;
  };

  modules = [
    { _module.args.lib = ext-lib; }
  ]
  ++ flake.rebellion.modules.homes
  # Import all home modules recursively
  ++ (ext-lib.import-modules-recursive ../../../modules/home { })
  ++ modules;
}
