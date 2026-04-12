_: {
  rbn.programs._.desktop._.utils._.appcleaner.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.appcleaner ];
    };
}
