{
  rbn.programs._.emulators._.alacritty = {
    homeManager =
      { pkgs, lib, ... }:
      {
        programs.alacritty = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.alacritty;
        };
      };

    darwin.homebrew.casks = [ "alacritty" ];
  };
}
