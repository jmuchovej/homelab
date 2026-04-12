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
  };

  rbn.system._.homebrew.darwin =
    { host, lib, ... }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];
      environment.systemPath = [ "/opt/homebrew/bin" ];

      homebrew = lib.mkIf host.homebrew.enable {
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

      nix-homebrew = lib.mkIf host.homebrew.enable {
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
