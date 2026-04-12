_: {
  rbn.programs._.desktop._.utils._.stats.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.stats ];
    };
}
