{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core.url = "github:homebrew/homebrew-core";
    homebrew-core.flake = false;
    homebrew-cask.url = "github:homebrew/homebrew-cask";
    homebrew-cask.flake = false;
    homebrew-bundle.url = "github:homebrew/homebrew-bundle";
    homebrew-bundle.flake = false;
    homebrew-services.url = "github:homebrew/homebrew-services";
    homebrew-services.flake = false;
    homebrew-fvm.url = "github:leoafarias/fvm";
    homebrew-fvm.flake = false;
  };

  den.defaults.darwin = {
    imports = [
      inputs.nix-homebrew.darwinModules.nix-homebrew
    ];
  };

  rbn.system._.homebrew.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew = {
        enable = true;

        global = {
          brewfile = true;
          autoUpdate = true;
        };

        onActivation = {
          autoUpdate = true;
          cleanup = "uninstall";
          upgrade = true;
        };

        brews = [ ];
      };

      nix-homebrew = {
        enable = true;
        user = host.user.name;

        taps = {
          "homebrew/core" = inputs.homebrew-core;
          "homebrew/cask" = inputs.homebrew-cask;
          "homebrew/bundle" = inputs.homebrew-bundle;
          "homebrew/services" = inputs.homebrew-services;
        };
      };
    };
}
