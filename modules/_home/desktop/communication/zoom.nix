{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.zoom";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.zoom-us ];
    };
}
