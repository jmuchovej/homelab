{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "desktop.spotify";
  conditions = { config, ... }: config.rebellion.desktop.enable;
  config =
    {
      cfg,
      lib,
      pkgs,
      config,
      ...
    }:
    let
      brew = config.rebellion.homebrew;
      inherit (config.rebellion.desktop) notunes;
    in
    {
      homebrew = lib.mkIf brew.enable {
        casks = [ "spotify" ];
      };
      system.defaults.CustomUserPreferences = lib.mkIf notunes.enable {
        twisted.noTunes.replacement =
          if brew.enable then "/Applications/Spotify.app" else "${pkgs.spotify}/Applications/Spotify.app";
      };
    };
}
