{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.desktop.spotify;
  notunes = config.rebellion.desktop.notunes;
  desktop = config.rebellion.desktop;
in
{
  options.rebellion.desktop.spotify = {
    enable = mkEnableOption "Spotify";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    environment.systemPackages = [ pkgs.spotify ];

    system.defaults.CustomUserPreferences = mkIf notunes.enable {
      twisted.noTunes.replacement = "${pkgs.spotify}/Applications/Spotify.app";
    };
  };
}
