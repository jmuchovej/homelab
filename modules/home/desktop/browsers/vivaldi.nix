{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.vivaldi";
  config =
    {
      cfg,
      config,
      pkgs,
      ...
    }:
    {
      programs.vivaldi = {
        enable = true;

        # extensions = with pkgs.chromium-extensions; [
        # ];
      };
    };
}
