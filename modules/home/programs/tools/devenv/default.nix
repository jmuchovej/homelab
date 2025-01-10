{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.devenv;
in {
  options.${namespace}.programs.tools.devenv = {
    enable = mkEnableOption "devenv";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      devenv
    ];

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
