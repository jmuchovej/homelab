_: {
  rbn.programs._.creativity._.sketch.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "sketch" ];
    };
}
