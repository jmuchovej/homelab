{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.arc";
  conditions = { pkgs, ... }: pkgs.stdenv.isDarwin;
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.arc-browser ];
    };
}
