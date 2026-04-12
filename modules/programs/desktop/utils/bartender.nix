_: {
  rbn.programs._.desktop._.utils._.bartender.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.bartender ];
    };
}
