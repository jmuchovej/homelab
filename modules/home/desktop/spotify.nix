{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.spotify";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.spotify ];
    };
}
