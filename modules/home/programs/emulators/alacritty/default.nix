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

  cfg = config.${namespace}.programs.emulators.alacritty;
in
{
  options.${namespace}.programs.emulators.alacritty = {
    enable = mkEnableOption "Alacritty";
  };

  config = mkIf cfg.enable {
    programs.alacritty = {
      enable = config.${namespace}.suites.desktop.enable;
      package = pkgs.alacritty;
    };
  };
}
