{
  rbn.programs._.desktop = {
    _.amie = {
      macos.homebrew.casks = [ "amie" ];
    };
    _.superwhisper = {
      macos.homebrew.casks = [ "superwhisper" ];
    };

    _.balenaetcher = {
      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.etcher ];
      };

      macos.homebrew.casks = [ "balenaetcher" ];
    };

    _.openconnect.hm = { pkgs, ... }: {
      home.packages = [ pkgs.openconnect_openssl ];
    };

    _.setapp = {
      macos.homebrew.casks = [ "setapp" ];
    };

    _.things = {
      macos.homebrew.masApps = {
        # "Things" = 904280696;
      };
    };

    _.utils = {
      _.alt-tab = {
        macos.homebrew.casks = [ "alt-tab" ];
      };
      _.appcleaner = {
        macos.homebrew.casks = [ "appcleaner" ];
      };
      _.bartender = {
        macos.homebrew.casks = [ "bartender" ];
      };

      _.blueutil = {
        macos = { pkgs, ... }: {
          environment.systemPackages = [ pkgs.blueutil ];
        };
      };

      _.hammerspoon = {
        macos.homebrew.casks = [ "hammerspoon" ];
      };
      _.launchcontrol = {
        macos.homebrew.casks = [ "launchcontrol" ];
      };
      _.logi-options = {
        macos.homebrew.casks = [ "logi-options+" ];
      };
      _.monitorcontrol = {
        macos.homebrew.casks = [ "monitorcontrol" ];
      };
      _.raycast = {
        macos =
          { lib, ... }:
          let
            inherit (lib.rbn.macos) keycode symbolic-hotkey;
          in
          {
            homebrew.casks = [ "raycast" ];
            system.defaults.CustomUserPreferences = {
              "com.raycast.macos".raycastGlobalHotkey = "Command-${toString (keycode " ")}";
              # Spotlight search (⌘Space) and Finder search window (⌥⌘Space),
              # disabled so Raycast owns ⌘Space.
              "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
                "64" = symbolic-hotkey false "cmd + ' '";
                "65" = symbolic-hotkey false "alt + cmd + ' '";
              };
            };
          };
      };
      _.sf-symbols = {
        macos.homebrew.casks = [ "sf-symbols" ];
      };
      _.stats = {
        macos.homebrew.casks = [ "stats" ];
      };

      _.switchaudio = {
        macos = { pkgs, ... }: {
          environment.systemPackages = [ pkgs.switchaudio-osx ];
        };
      };

      _.xquartz = {
        macos.homebrew.casks = [ "xquartz" ];
      };
    };
  };
}
