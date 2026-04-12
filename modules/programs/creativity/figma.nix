_: {
  rbn.programs._.creativity._.figma = {
    # TODO: no nixpkg named 'figma' for Linux
    homeManager = { };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "figma" ];
      };
  };
}
