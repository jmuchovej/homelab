_: {
  rbn.programs._.media = {
    provides.ferium = {
      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = with pkgs; [
              ferium
            ];
        };
    };

    provides.plex = {
      # TODO: needs upstream nixpkg support for plex-desktop and plexamp
      homeManager = { };

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [
            "plex"
            "plexamp"
          ];
        };
    };

    provides.spotify = {
      dock.app = "Spotify.app";

      homeManager =
        { pkgs, lib, ... }:
        {
          home.packages = lib.mkIf pkgs.stdenv.isLinux [ pkgs.spotify ];
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
  };
}
