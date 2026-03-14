{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.rio";
  config =
    { pkgs, ... }:
    {
      programs.rio = {
        enable = true;
        package = pkgs.rio;
      };
    };
}
