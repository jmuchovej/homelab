{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "programs.desktop.pkm.waypoints";
  config =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        waypoints
        waypoints-atlas
      ];
    };
}
