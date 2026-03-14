{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.beeper";
  config =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # TODO `beeper` isn't built for macOS (yet)
        # beeper
        beeper-bridge-manager
      ];
    };
}
