{
  rbn.programs._.browsers._.vivaldi = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.vivaldi.enable = lib.mkIf pkgs.stdenv.isLinux true;
      };

    darwin.homebrew.casks = [ "vivaldi" ];
  };
}
