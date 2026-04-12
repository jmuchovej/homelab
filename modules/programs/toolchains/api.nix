_: {
  rbn.programs._.toolchains._.api = {
    provides = {
      bruno = {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [ pkgs.bruno ];
            rebellion.dock.entries = [
              {
                name = "Bruno.app";
                source = "hm";
                group = "editors";
                order = 520;
              }
            ];
          };
      };
      postman = {
        homeManager =
          { pkgs, ... }:
          {
            home.packages = [ pkgs.postman ];
          };
      };
    };
  };
}
