_: {
  rbn.programs._.desktop._.setapp.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "setapp" ];
    };
}
