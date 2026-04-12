_: {
  rbn.programs._.desktop._.utils._.stats.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "stats" ];
    };
}
