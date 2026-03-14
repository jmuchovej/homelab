{ inputs, lib, ... }:
{
  flake-file.inputs.home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default.nixos = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
  };

  den.default.darwin = {
    imports = [ inputs.home-manager.darwinModules.home-manager ];
  };

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];
  den.default.home-manager.home.stateVersion = lib.mkDefault "25.11";
}
