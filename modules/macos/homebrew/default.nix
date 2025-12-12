{
  config,
  lib,
  namespace,
  inputs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (inputs)
    homebrew-core
    homebrew-cask
    homebrew-bundle
    homebrew-services
    ;

  cfg = config.rebellion.homebrew;
in
{
  config = mkIf cfg.enable {
    nix-homebrew = {
      enable = true;
      user = config.rebellion.user.name;

      taps = {
        "homebrew/homebrew-core" = homebrew-core;
        "homebrew/homebrew-cask" = homebrew-cask;
        "homebrew/bundle" = homebrew-bundle;
        "homebrew/services" = homebrew-services;
      };
    };

    homebrew = {
      brews = [ ];

      casks = [
        "1password"
        "arc"
        "anytype" # TODO contrib Nix support for macOS
        "setapp"
        "beeper" # TODO contrib Nix support for macOS
        "amie"
        "logi-options+"
        "firefox@developer-edition"
        "pdf-expert"
        "pdfelement"
        "gpg-suite"
        "notion"
        "notion-calendar"
        "logseq" # TODO contrib Nix support for macOS
        "obsidian" # TODO contrib Nix support for macOS
        "hammerspoon"
        "launchcontrol"
        "sf-symbols"
        "xquartz" # TODO migrate back to `modules/home` once refactor is complete?
        "orcaslicer" # TODO contrib Nix support for macOS
        "openscad@snapshot" # TODO contrib Nix support for macOS – there's some Qt6 error when installing
        "balenaetcher" # TODO contrib Nix support for macOS?
        "protonvpn" # TODO contrib Nix support for macOS?
        "zoom" # TODO migrate back to `modules/home` once refactor is complete
        "sketch"
        "hammerspoon"
        "notunes"
        "obs"
        "powershell"
        "protonvpn"
        "ticktick"
      ];

      masApps = mkIf config.rebellion.homebrew.mas.enable {
        # "AutoMounter"               = 1160435653;
        "Amphetamine" = 937984704;
        # "Dark Reader for Safari"    = 1438243180;
        "Magnet" = 441258766;
        # "Microsoft Remote Desktop"  = 1295203466;
        "reMarkable" = 1276493162;
        "TestFlight" = 899247664;
        "Velja" = 1607635845;
        "Things 3" = 904280696;
        "Structured - Daily Planner" = 1499198946;
      };
    };
  };
}
