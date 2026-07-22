{ den, ... }:
{
  rbn.programs._.toolchains._.api = {
    _.bruno = {
      dock.app = "Bruno.app";

      homeManager =
        { pkgs, ... }:
        {
          home.packages = [ pkgs.bruno ];
        };
    };

    _.postman = {
      includes = [ (den.batteries.unfree [ "postman" ]) ];

      homeManager =
        { pkgs, lib, ... }:
        lib.mkIf pkgs.stdenv.isLinux {
          home.packages = [ pkgs.postman ];
        };

      darwin.homebrew.casks = [ "postman" ];
    };
  };
}
