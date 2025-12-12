{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.programs.apps.notunes;
in {
  options.rebellion.programs.apps.notunes = {
    enable = mkEnableOption "NoTunes";
  };

  config = mkIf cfg.enable {
    homebrew.casks = ["notunes"];
  };
}
