{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.zulip";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.zulip ];
    };
}
