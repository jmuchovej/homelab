_: {
  rbn.programs._.emulators._.alacritty = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.alacritty = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.alacritty;
        };
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "alacritty" ];
      };
  };
}
