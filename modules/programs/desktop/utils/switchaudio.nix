_: {
  rbn.programs._.desktop._.utils._.switchaudio.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.switchaudio-osx ];
    };
}
