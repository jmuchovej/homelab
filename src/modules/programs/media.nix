{ den, ... }: {
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
      includes = [
        (den.batteries.unfree [ "spotify" ])
      ];

      dock.app = "Spotify.app";

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.spotify ];
      };

      macos = { pkgs, ... }: {
        homebrew.casks = [ "notunes" ];

        system.defaults.CustomUserPreferences = {
          twisted.noTunes.replacement = "${pkgs.spotify}/Applications/Spotify.app";
        };
      };
    };
  };
}
