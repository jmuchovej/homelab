{
  config,
  # inputs,
  lib,
  pkgs,
  # system,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.desktop.ghostty;
  desktop = config.${namespace}.suites.desktop;
in {
  options.${namespace}.desktop.ghostty = {
    enable = mkEnableOption "Ghostty";
  };

  # https://github.com/nix-community/home-manager/pull/6235
  config = mkIf cfg.enable && desktop.enable {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
    };
  };
}
