{ den, ... }:
{
  rbn.programs._.toolchains._.api = {
    provides.bruno = {
      dock.app = "Bruno.app";

      homeManager =
        { pkgs, ... }:
        {
          home.packages = [ pkgs.bruno ];
        };
    };
    provides.postman = {
      includes = [ (den.provides.unfree [ "postman" ]) ];

      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.postman ];
        };

      darwin =
        { host, lib, ... }:
        lib.mkIf host.homebrew.enable {
          homebrew.casks = [ "postman" ];
        };
    };
  };
}
