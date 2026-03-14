{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.google-chrome";
  config = _: {
    programs.google-chrome = {
      enable = true;

      # extensions = with pkgs.chromium-extensions; [
      # ];
    };
  };
}
