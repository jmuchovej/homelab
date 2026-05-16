_: {
  rbn.programs._.desktop._.utils._.raycast.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "raycast" ];
    };
}
