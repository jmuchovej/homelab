_: {
  rbn.programs._.browsers._.vivaldi = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.vivaldi.enable = lib.mkIf pkgs.stdenv.isLinux true;
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "vivaldi" ];
      };
  };
}
