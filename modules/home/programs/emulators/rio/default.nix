{
  config,
  # inputs,
  lib,
  pkgs,
  # system,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.emulators.rio;
in
{
  options.${namespace}.programs.emulators.rio = {
    enable = mkEnableOption "Rio";
  };

  config = mkIf cfg.enable {
    programs.rio = {
      enable = config.${namespace}.suites.desktop.enable;
      package = pkgs.rio;
    };
  };
}
