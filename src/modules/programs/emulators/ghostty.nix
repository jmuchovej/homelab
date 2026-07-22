{
  rbn.programs._.emulators._.ghostty = {
    dock.app = "Ghostty.app";

    nixos = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.ghostty.terminfo ];
    };

    homeManager =
      { pkgs, lib, ... }:
      {
        programs.ghostty = lib.mkIf pkgs.stdenv.isLinux {
          enable = true;
          package = pkgs.ghostty;
        };
      };

    darwin.homebrew.casks = [ "ghostty" ];
  };
}
