_: {
  rbn.programs._.media._.plex = {
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
}
