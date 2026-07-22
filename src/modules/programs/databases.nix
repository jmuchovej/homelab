{
  rbn.programs._.databases = {
    _.beekeeper = {
      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.beekeeper-studio ];
        };
      darwin.homebrew.casks = [ "beekeeper-studio" ];
    };
    _.dbeaver = {
      homeManager =
        { pkgs, ... }:
        {
          home.packages = [ pkgs.dbeaver-bin ];
        };
    };
  };
}
