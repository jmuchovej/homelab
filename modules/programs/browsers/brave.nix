_: {
  rbn.programs._.browsers._.brave = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.brave.enable = lib.mkIf pkgs.stdenv.isLinux true;

        rebellion.dock.entries = [
          {
            name = "Brave Browser.app";
            source = "applications";
            group = "browsers";
            order = 310;
          }
        ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "brave-browser" ];
      };
  };
}
