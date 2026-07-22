{
  rbn.programs._.browsers._.google-chrome = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.google-chrome.enable = lib.mkIf pkgs.stdenv.isLinux true;
      };

    darwin.homebrew.casks = [ "google-chrome" ];
  };
}
