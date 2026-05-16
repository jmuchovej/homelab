_: {
  rbn.programs._.desktop._.utils._.logi-options.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "logi-options+" ];
    };
}
