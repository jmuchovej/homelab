{ inputs, lib, ... }:
{
  flake-file.inputs.home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default = {
    nixos.imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    darwin.imports = [
      inputs.home-manager.darwinModules.home-manager
    ];
    homeManager = { lib, ... }: {
      home.stateVersion = lib.mkDefault "25.11";
      home.sessionPath = [ "$HOME/.local/bin" ];
      xdg.enable = true;
    };
  };

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  rbn.system._.home-manager.os = {
    home-manager = {
      backupFileExtension = "hm.bak";
      useUserPackages = true;
      useGlobalPkgs = true;
      verbose = true;
    };
  };
}
