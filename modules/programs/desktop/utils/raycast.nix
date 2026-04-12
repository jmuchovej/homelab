_: {
  rbn.programs._.desktop._.utils._.raycast.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.raycast ];
    };
}
