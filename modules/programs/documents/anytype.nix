_: {
  rbn.programs._.documents._.anytype = {
    homeManager =
      { pkgs, lib, ... }:
      lib.mkIf pkgs.stdenv.isLinux {
        home.packages = [ pkgs.anytype ];
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "anytype" ];
      };
  };
}
