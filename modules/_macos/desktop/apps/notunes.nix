{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "desktop.notunes";
  options =
    { lib, ... }:
    {
      replacement = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to replacement audio app";
        example = "\${pkgs.spotify}/Applications/Spotify.app";
      };
    };
  config =
    { cfg, lib, ... }:
    {
      homebrew.casks = [ "notunes" ];
      system.defaults.CustomUserPreferences = lib.mkIf (cfg.replacement != null) {
        twisted.noTunes.replacement = cfg.replacement;
      };
    };
}
