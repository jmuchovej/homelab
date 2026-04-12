_: {
  rbn.programs._.desktop._.utils._.appcleaner.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "appcleaner" ];
    };
}
