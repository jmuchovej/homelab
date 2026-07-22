{
  rbn.programs._.emulators._.rio = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.rio = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.rio;
        };
      };

    darwin.homebrew.casks = [ "rio" ];
  };
}
