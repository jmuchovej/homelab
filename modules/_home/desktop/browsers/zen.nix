{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.zen";
  conditions = { pkgs, ... }: pkgs.stdenv.isLinux;
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.zen-browser ];
    };
}
