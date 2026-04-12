_: {
  rbn.programs._.desktop._.utils._.hammerspoon.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "hammerspoon" ];
    };
}
