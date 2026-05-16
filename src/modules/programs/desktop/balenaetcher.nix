_: {
  rbn.programs._.desktop._.balenaetcher = {
    homeManager =
      { pkgs, lib, ... }:
      lib.mkIf pkgs.stdenv.isLinux {
        home.packages = [ pkgs.etcher ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "balenaetcher" ];
      };
  };
}
