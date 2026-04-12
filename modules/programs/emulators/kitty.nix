_: {
  rbn.programs._.emulators._.kitty = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.kitty = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.kitty;
        };
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "kitty" ];
      };
  };
}
