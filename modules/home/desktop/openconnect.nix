{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.openconnect";
  config =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.openconnect_openssl ];
    };
}
