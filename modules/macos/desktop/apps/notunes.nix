{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types
    ;

  cfg = config.rebellion.desktop.notunes;
in
{
  options.rebellion.desktop.notunes = {
    enable = mkEnableOption "NoTunes";
    replacement = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to replacement audio app";
      example = "\${pkgs.spotify}/Applications/Spotify.app";
    };
  };

  config = mkIf cfg.enable {
    homebrew.casks = [ "notunes" ];

    system.defaults.CustomUserPreferences = mkIf (cfg.replacement != null) {
      twisted.noTunes.replacement = cfg.replacement;
    };
  };
}
