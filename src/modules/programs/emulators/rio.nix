_: {
  rbn.programs._.emulators._.rio = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.rio = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.rio;
        };
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "rio" ];
      };
  };
}
