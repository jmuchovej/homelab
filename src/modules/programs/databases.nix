_: {
  rbn.programs._.databases = {
    provides = {
      beekeeper = {
        homeManager =
          { pkgs, lib, ... }:
          lib.mkIf pkgs.stdenv.isLinux {
            home.packages = [ pkgs.beekeeper-studio ];
          };
        darwin =
          { host, lib, ... }:
          lib.mkIf host.homebrew.enable {
            homebrew.casks = [ "beekeeper-studio" ];
          };
      };
      dbeaver = {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [ pkgs.dbeaver-bin ];
          };
      };
    };
  };
}
