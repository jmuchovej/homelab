{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.vivaldi";
  config = _: {
    programs.vivaldi = {
      enable = true;

      # extensions = with pkgs.chromium-extensions; [
      # ];
    };
  };
}
