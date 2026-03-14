{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.obsidian";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.obsidian ];

      rebellion.dock.entries = [
        {
          name = "Obsidian.app";
          source = "applications";
          group = "pkm";
          order = 410;
        }
      ];
    };
}
