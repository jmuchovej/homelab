_: {
  rbn.programs._.browsers._.brave = {
    dock.app = "Brave Browser.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        programs.brave.enable = lib.mkIf pkgs.stdenv.isLinux true;
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "brave-browser" ];
      };
  };
}
