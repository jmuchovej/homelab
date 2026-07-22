{
  rbn.programs._.browsers._.brave = {
    dock.app = "Brave Browser.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        programs.brave.enable = lib.mkIf pkgs.stdenv.isLinux true;
      };

    darwin.homebrew.casks = [ "brave-browser" ];
  };
}
