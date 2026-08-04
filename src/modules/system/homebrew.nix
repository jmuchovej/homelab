{
  flake-file.inputs = {
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core.url = "github:homebrew/homebrew-core";
    homebrew-core.flake = false;
    homebrew-cask.url = "github:homebrew/homebrew-cask";
    homebrew-cask.flake = false;
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

  rbn.system._.homebrew.macos = { inputs, host, ... }: {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    environment.systemPath = [ "/opt/homebrew/bin" ];

    homebrew = {
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
        autoUpdate = false;
        cleanup = "uninstall";
        upgrade = false;
      };
    };

    nix-homebrew = {
      enable = true;
      user = host.primary-user.name;

      enableRosetta = false;

      taps = {
        "homebrew/core" = inputs.homebrew-core;
        "homebrew/cask" = inputs.homebrew-cask;
        "homebrew/services" = inputs.homebrew-services;
      };
    };
  };
}
