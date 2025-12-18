{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.appflowy";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.appflowy ];
    };
}
