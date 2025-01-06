{
  config,
  lib,
  namespace,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (lib.${namespace}) get-shared enabled;

  cfg = config.${namespace}.suites.desktop;
in {
  imports = [
    (get-shared "suites/desktop")
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
      xquartz
    ];

    ${namespace} = {
      programs = {
        browsers.arc = mkDefault enabled;
        apps.notunes = mkDefault enabled;
        apps.onepassword = mkDefault enabled;
      };

      # desktop = {
      #   statusbars = {
      #     sketchybar = mkDefault enabled;
      #   };

      #   wms = {
      #     yabai = mkDefault enabled;
      #   };
      # };
    };

    homebrew = {
      brews = [];

      casks = [
        "anytype" # TODO contrib Nix support for macOS
        "setapp"
        "alfred"
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
        "xquartz"
        "bambu-studio" # TODO contrib Nix support for macOS
        "balenaetcher"
      ];

      taps = [
        "beeftornado/rmtree"
        "felixkratz/homebrew-formulae"
        "khanhas/tap"
      ];

      masApps = mkIf config.${namespace}.homebrew.mas.enable {
        # "AutoMounter"               = 1160435653;
        "Amphetamine" = 937984704;
        # "Dark Reader for Safari"    = 1438243180;
        "Magnet" = 441258766;
        # "Microsoft Remote Desktop"  = 1295203466;
        "reMarkable" = 1276493162;
        "TestFlight" = 899247664;
        "Velja" = 1607635845;
        "Things 3" = 904280696;
      };
    };
  };
}
