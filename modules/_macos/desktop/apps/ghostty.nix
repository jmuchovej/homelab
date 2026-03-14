{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "desktop.ghostty";
  conditions = { config, ... }: config.rebellion.desktop.enable;
  config =
    {
      cfg,
      lib,
      config,
      ...
    }:
    let
      brew = config.rebellion.homebrew;
    in
    {
      # environment.systemPackages = [ pkgs.ghostty ];
      homebrew = lib.mkIf brew.enable {
        casks = [ "ghostty" ];
      };
    };
}
