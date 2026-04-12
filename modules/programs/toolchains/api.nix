_: {
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
      homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.postman ];
      };
    };
  };
}
