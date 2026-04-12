_: {
  rbn.programs._.desktop._.utils._.monitorcontrol.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.monitorcontrol ];
    };
}
