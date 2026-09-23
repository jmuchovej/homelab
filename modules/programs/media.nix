{
  rbn.programs._.media = {
    _.ferium = {
      hm = { pkgs, ... }: {
        home.packages = [ pkgs.ferium ];
      };
    };

    _.plex = {
      # TODO: needs upstream nixpkg support for plex-desktop and plexamp
      hm = _: { };

      macos.homebrew.casks = [
        "plex"
        "plexamp"
      ];
    };

    _.spotify = {
      dock.app = "Spotify.app";

      hm-macos = { pkgs, ... }: {
        home.packages = [ pkgs.rbn.no-tunes ];

        launchd.agents.no-tunes = {
          enable = true;
          config = {
            ProgramArguments = [
              "${pkgs.rbn.no-tunes}/Applications/noTunes.app/Contents/MacOS/noTunes"
            ];
            RunAtLoad = true;
            ProcessType = "Interactive";
          };
        };

        targets.darwin.defaults."digital.twisted.noTunes" = {
          replacement = "/Applications/Spotify.app";
          hideIcon = 1;
        };
      };

      macos.homebrew.casks = [ "spotify" ];
    };
  };
}
