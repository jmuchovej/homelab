{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.shell;
in {
  options.rebellion.shell = {
    enable = mkEnableOption "shell";
  };

  config = mkIf cfg.enable {
  };
}
