{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "programs.desktop.figma";
  config =
    { lib, pkgs, ... }:
    let
      inherit (pkgs.stdenv) isDarwin isLinux;
    in
    {
      rebellion.homebrew.casks = lib.mkIf isDarwin [ "figma" ];

      home.pakages = lib.mkIf isLinux [
        pkgs.figma
      ];
    };
}
