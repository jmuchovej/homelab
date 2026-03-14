{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.ghostty";
  config =
    { pkgs, ... }:
    {
      # https://github.com/nix-community/home-manager/pull/6235
      programs.ghostty = {
        enable = true;
        package = pkgs.ghostty;
      };

      rebellion.dock.entries = [
        {
          name = "Ghostty.app";
          source = "applications";
          group = "terminals";
          order = 620;
        }
      ];
    };
}
