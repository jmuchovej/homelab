{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.alacritty";
  config =
    { pkgs, ... }:
    {
      programs.alacritty = {
        enable = true;
        package = pkgs.alacritty;
      };
    };
}
