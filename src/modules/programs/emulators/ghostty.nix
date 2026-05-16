_: {
  rbn.programs._.emulators._.ghostty = {
    dock.app = "Ghostty.app";

    homeManager =
      { pkgs, lib, ... }:
      {
        programs.ghostty = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.ghostty;
        };
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "ghostty" ];
      };
  };
}
