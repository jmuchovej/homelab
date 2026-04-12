_: {
  rbn.programs._.emulators._.ghostty = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.ghostty = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.ghostty;
        };

        rebellion.dock.entries = [
          {
            name = "Ghostty.app";
            source = "applications";
            group = "terminals";
            order = 620;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "ghostty" ];
      };
  };
}
