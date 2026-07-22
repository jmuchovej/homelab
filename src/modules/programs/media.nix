{
  rbn.programs._.media = {
    _.ferium = {
      homeManager =
        { pkgs, ... }:
        {
          home.packages = [ pkgs.ferium ];
        };
    };

    _.plex = {
      # TODO: needs upstream nixpkg support for plex-desktop and plexamp
      homeManager = { };

      darwin.homebrew.casks = [
        "plex"
        "plexamp"
      ];
    };

    _.spotify = {
      dock.app = "Spotify.app";

      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.spotify ];
        };

      darwin = {
        homebrew.casks = [
          "spotify"
          "notunes"
        ];

        system.defaults.CustomUserPreferences = {
          twisted.noTunes.replacement = "/Applications/Spotify.app";
        };
      };
    };
  };
}
