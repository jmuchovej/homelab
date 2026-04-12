_: {
  rbn.programs._.desktop._.utils._.bartender.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "bartender" ];
    };
}
