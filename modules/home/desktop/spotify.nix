{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf optionals mkEnableOption;
  inherit (lib.rebellion) enabled;

  cfg = config.rebellion.programs.desktop.spotify;
  notunes = config.rebellion.programs.desktop.notunes;
  desktop = config.rebellion.desktop;
in
{
  options.rebellion.programs.desktop.spotify = {
    enable = mkEnableOption "Spotify";
  };

  config =
    mkIf cfg.enable
    && desktop.enable {
      home.packages = [ pkgs.spotify ];
      system.defaults.twisted.noTunes.replacement = "${pkgs.spotify}/Applications/Spotify.app";
    };
}
