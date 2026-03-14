{ inputs, ... }:
{
  flake-file.inputs = {
    nix-index-database.url = "github:nix-community/nix-index-database";
  };

  den.default.nixos = {
    imports = [ inputs.nix-index-database.nixosModules.nix-index ];
    nixpkgs.config.allowUnfree = true;
    programs.nix-index-database.comma.enable = true;
    programs.nix-ld.enable = true;

    nix = {
      optimise.automatic = true;
      registry.nixpkgs.flake = inputs.nixpkgs;
      gc.automatic = true;
      settings = {
        keep-outputs = true;
        keep-derivations = true;
        use-xdg-base-directories = true;
        auto-optimise-store = true;
      };
    };
  };

  den.default.darwin = {
    imports = [ inputs.nix-index-database.darwinModules.nix-index ];
    nixpkgs.config.allowUnfree = true;
    programs.nix-index-database.comma.enable = true;

    nix = {
      optimise.automatic = true;
      registry.nixpkgs.flake = inputs.nixpkgs;
      gc.automatic = true;
      settings = {
        keep-outputs = true;
        keep-derivations = true;
        use-xdg-base-directories = true;
        auto-optimise-store = true;
      };
    };
  };

  den.default.homeManager = {
    imports = [ inputs.nix-index-database.homeModules.nix-index ];
    programs.nix-index-database.comma.enable = true;
  };
}
