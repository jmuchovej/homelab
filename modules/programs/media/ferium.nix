_: {
  rbn.programs._.media._.ferium.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ferium ];
    };
}
