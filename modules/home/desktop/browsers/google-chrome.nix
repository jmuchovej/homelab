{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.google-chrome";
  config =
    {
      cfg,
      config,
      pkgs,
      ...
    }:
    {
      programs.google-chrome = {
        enable = true;

        # extensions = with pkgs.chromium-extensions; [
        # ];
      };
    };
}
