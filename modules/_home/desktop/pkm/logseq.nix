{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.logseq";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.logseq ];

      rebellion.dock.entries = [
        {
          name = "Logseq.app";
          source = "hm";
          group = "pkm";
          order = 440;
        }
      ];
    };
}
