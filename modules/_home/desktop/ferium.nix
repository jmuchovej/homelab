{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.ferium";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ferium ];
    };
}
