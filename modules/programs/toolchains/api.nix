{ den, ... }: {
  rbn.programs._.toolchains._.api = {
    _.bruno = {
      dock.key = "Bruno";
      dock.source = "hm";

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.bruno ];
      };
    };

    _.postman = {
      includes = [ (den.batteries.unfree [ "postman" ]) ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.postman ];
      };
    };
  };
}
