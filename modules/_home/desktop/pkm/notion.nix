{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.notion";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.notion-app ];

      rebellion.dock.entries = [
        {
          name = "Notion.app";
          source = "hm";
          group = "pkm";
          order = 420;
        }
      ];
    };
}
