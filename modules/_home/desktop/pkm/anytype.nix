{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.anytype";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.anytype ];
    };
}
