_: {
  rbn.programs._.desktop._.utils._.monitorcontrol.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "monitorcontrol" ];
    };
}
