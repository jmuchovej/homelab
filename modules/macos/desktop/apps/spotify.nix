{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.desktop.spotify;
  inherit (config.rebellion) desktop;
  inherit (config.rebellion.desktop) notunes;
  brew = config.rebellion.homebrew;
in
{
  options.rebellion.desktop.spotify = {
    enable = mkEnableOption "Spotify";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    # environment.systemPackages = [ pkgs.spotify ];
    homebrew = mkIf brew.enable {
      casks = [ "spotify" ];
    };

    system.defaults.CustomUserPreferences = mkIf notunes.enable {
      twisted.noTunes.replacement =
        if brew.enable then "/Applications/Spotify.app" else "${pkgs.spotify}/Applications/Spotify.app";
    };
  };
}
