{ den, ... }: {
  rbn.programs._.databases = {
    _.beekeeper = {
      includes = [
        (den.batteries.insecure [ "beekeeper-studio-6.0.5" ])
      ];

      hm = { pkgs, ... }: {
        home.packages = [ pkgs.beekeeper-studio ];
      };
    };

    _.dbeaver = {
      hm = { pkgs, ... }: {
        home.packages = [ pkgs.dbeaver-bin ];
      };
    };
  };
}
