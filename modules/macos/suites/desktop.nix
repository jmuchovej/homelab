{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.rebellion) get-file enabled;

  cfg = config.rebellion.suites.desktop;
  brew = config.rebellion.homebrew;
in
{
  imports = [
    (get-file "modules/common/suites/desktop.nix")
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      alt-tab-macos
      appcleaner
      bartender
      blueutil
      monitorcontrol
      raycast
      switchaudio-osx
      stats
      # TODO `xquartz` is broken on macOS 26.1+
      # xquartz
    ];

    rebellion = {
      desktop = enabled // {
        # browsers.arc = mkDefault enabled;
        onepassword = mkDefault enabled;
      };

      #   statusbars = {
      #     sketchybar = mkDefault enabled;
      #   };

      #   wms = {
      #     yabai = mkDefault enabled;
      #   };
    };

    homebrew = mkIf brew.enable {
      casks = [
        "anytype" # TODO contrib Nix support for macOS
        "setapp"
        "beeper" # TODO contrib Nix support for macOS
        "amie"
        "notion"
        "notion-calendar"
        "logi-options+"
        "firefox@developer-edition"
        "pdf-expert"
        "gpg-suite"
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
        "pdfelement"
        "sketch"
      ];

      masApps = mkIf brew.mas.enable {
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
