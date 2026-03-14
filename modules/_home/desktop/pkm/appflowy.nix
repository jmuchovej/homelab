{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.appflowy";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.appflowy ];

      rebellion.dock.entries = [
        {
          name = "Appflowy.app";
          source = "hm";
          group = "pkm";
          order = 450;
        }
      ];
    };
}
