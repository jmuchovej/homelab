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

  cfg = config.rebellion.desktop.ghostty;
  desktop = config.rebellion.desktop;
in {
  options.rebellion.desktop.ghostty = {
    enable = mkEnableOption "Ghostty";
  };

  # https://github.com/nix-community/home-manager/pull/6235
  config = mkIf (cfg.enable && desktop.enable) {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
    };
  };
}
