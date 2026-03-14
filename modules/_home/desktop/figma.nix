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

      home.packages = lib.mkIf isLinux [
        # pkgs.figma # TODO: no nixpkg named 'figma' — use figma-agent or Homebrew cask
      ];
    };
}
