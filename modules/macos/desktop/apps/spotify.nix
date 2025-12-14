{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (pkgs) spotify;

  cfg = config.rebellion.desktop.spotify;
  desktop = config.rebellion.desktop;
  notunes = config.rebellion.desktop.notunes;
  brew = config.rebellion.homebrew;
in
{
  options.rebellion.desktop.spotify = {
    enable = mkEnableOption "Spotify";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    # environment.systemPackages = [ spotify ];
    homebrew = mkIf (brew.enable) {
      casks = [ "spotify" ];
    };

    system.defaults.CustomUserPreferences = mkIf (notunes.enable) {
      twisted.noTunes.replacement =
        if brew.enable then "/Applications/Spotify.app" else "${spotify}/Applications/Spotify.app";
    };
  };
}
