{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.apps.notunes;
in {
  options.${namespace}.programs.apps.notunes = {
    enable = mkEnableOption "NoTunes";
  };

  config = mkIf cfg.enable {
    homebrew.casks = ["notunes"];
  };
}
