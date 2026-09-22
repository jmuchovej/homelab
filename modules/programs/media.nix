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

      macos = _: {
        homebrew.casks = [
          "notunes"
          "spotify"
        ];

        system.defaults.CustomUserPreferences = {
          "digital.twisted.noTunes".replacement = "/Applications/Spotify.app";
          "digital.twisted.noTunes".hideIcon = 1;
        };
      };
    };
  };
}
