{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.logseq";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.logseq ];
    };
}
