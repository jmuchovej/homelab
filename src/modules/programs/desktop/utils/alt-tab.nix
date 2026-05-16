_: {
  rbn.programs._.desktop._.utils._.alt-tab.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "alt-tab" ];
    };
}
