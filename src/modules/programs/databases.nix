{
  rbn.programs._.databases = {
    _.beekeeper = {
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
