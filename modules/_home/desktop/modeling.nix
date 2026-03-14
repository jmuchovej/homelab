{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.modeling";
  description = "3D Modeling";
  config =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) optionals;
      vsc = config.rebellion.editors.vscode;
    in
    {
      home.packages = with pkgs; [
        openscad-unstable
        # TODO this needs to be supported upstream
        # orca-slicer
      ];

      programs.vscode.extensions = optionals vsc.enable [
        pkgs.vscode-extensions.antyos.openscad
      ];
    };
}
