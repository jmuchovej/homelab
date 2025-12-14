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
in
{
  options.rebellion.desktop.spotify = {
    enable = mkEnableOption "Spotify";
  };

  config = mkIf (cfg.enable && config.rebellion.desktop.enable) {
    environment.systemPackages = [ pkgs.spotify ];

    system.defaults.CustomUserPreferences = mkIf (config.rebellion.desktop.notunes.enable) {
      twisted.noTunes.replacement = "${pkgs.spotify}/Applications/Spotify.app";
    };
  };
}
