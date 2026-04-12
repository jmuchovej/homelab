_: {
  rbn.programs._.desktop._.utils._.launchcontrol.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "launchcontrol" ];
    };
}
