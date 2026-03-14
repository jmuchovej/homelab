{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.kitty";
  config =
    { pkgs, ... }:
    {
      programs.kitty = {
        enable = true;
        package = pkgs.kitty;
      };
    };
}
