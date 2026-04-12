_: {
  rbn.programs._.desktop._.utils._.blueutil.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.blueutil ];
    };
}
