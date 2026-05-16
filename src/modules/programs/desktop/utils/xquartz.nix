_: {
  rbn.programs._.desktop._.utils._.xquartz.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "xquartz" ];
    };
}
