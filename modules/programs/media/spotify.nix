_: {
  rbn.programs._.media._.spotify = {
    homeManager =
      { pkgs, lib, ... }:
      {
        home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.spotify ];

        rebellion.dock.entries = [
          {
            name = "Spotify.app";
            source = "applications";
            group = "communication";
            order = 230;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      let
        brew = host.homebrew;
      in
      {
        homebrew = lib.mkIf brew.enable {
          casks = [
            "spotify"
            "notunes"
          ];
        };

        system.defaults.CustomUserPreferences = {
          twisted.noTunes.replacement = "/Applications/Spotify.app";
        };
      };
  };
}
