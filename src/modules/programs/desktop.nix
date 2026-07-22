{
  rbn.programs._.desktop = {
    _.amie.darwin.homebrew.casks = [ "amie" ];

    _.balenaetcher = {
      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.etcher ];
        };

      darwin.homebrew.casks = [ "balenaetcher" ];
    };

    _.openconnect.homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.openconnect_openssl ];
      };

    _.proton = {
      # TODO: needs upstream nixpkg support for protonmail-desktop, protonmail-bridge,
      # protonvpn-cli, proton-pass
      homeManager = { };

      darwin.homebrew.casks = [ "protonvpn" ];
    };

    _.setapp.darwin.homebrew.casks = [ "setapp" ];

    _.things.darwin.homebrew.masApps = {
      # "Things" = 904280696;
    };

    _.utils = {
      _.alt-tab.darwin.homebrew.casks = [ "alt-tab" ];
      _.appcleaner.darwin.homebrew.casks = [ "appcleaner" ];
      _.bartender.darwin.homebrew.casks = [ "bartender" ];

      _.blueutil.darwin =
        { pkgs, ... }:
        {
          environment.systemPackages = [ pkgs.blueutil ];
        };

      _.hammerspoon.darwin.homebrew.casks = [ "hammerspoon" ];
      _.launchcontrol.darwin.homebrew.casks = [ "launchcontrol" ];
      _.logi-options.darwin.homebrew.casks = [ "logi-options+" ];
      _.monitorcontrol.darwin.homebrew.casks = [ "monitorcontrol" ];
      _.raycast.darwin.homebrew.casks = [ "raycast" ];
      _.sf-symbols.darwin.homebrew.casks = [ "sf-symbols" ];
      _.stats.darwin.homebrew.casks = [ "stats" ];

      _.switchaudio.darwin =
        { pkgs, ... }:
        {
          environment.systemPackages = [ pkgs.switchaudio-osx ];
        };

      _.xquartz.darwin.homebrew.casks = [ "xquartz" ];
    };
  };
}
