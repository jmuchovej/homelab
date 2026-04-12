{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core.url = "github:homebrew/homebrew-core";
    homebrew-core.flake = false;
    homebrew-cask.url = "github:homebrew/homebrew-cask";
    homebrew-cask.flake = false;
    # homebrew-bundle was archived 2025-04-22; functionality moved into homebrew core.
    # Don't tap it — the archived version conflicts with the built-in bundle command.
    homebrew-services.url = "github:homebrew/homebrew-services";
    homebrew-services.flake = false;
  };

  # # nixpkgs.mas is 6.0.1 but homebrew installs 7.0.0+; the activation PATH
  # # puts the nix `mas` first which confuses `brew bundle` into re-installing
  # # `mas` forever. Override to use homebrew's `mas` directly.
  # den.default.darwin.nixpkgs.overlays = [
  #   (_final: prev: {
  #     mas = prev.runCommand "mas-homebrew-wrapper" { } ''
  #       mkdir -p $out/bin
  #       ln -s /opt/homebrew/bin/mas $out/bin/mas
  #     '';
  #   })
  # ];

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

        caskArgs = {
          appdir = "~/Applications";
          require_sha = true;
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

        enableRosetta = false;

        taps = {
          "homebrew/core" = inputs.homebrew-core;
          "homebrew/cask" = inputs.homebrew-cask;
          "homebrew/services" = inputs.homebrew-services;
        };
      };
    };
}
