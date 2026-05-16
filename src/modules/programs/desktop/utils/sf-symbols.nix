_: {
  rbn.programs._.desktop._.utils._.sf-symbols.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "sf-symbols" ];
    };
}
