{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.starship;
in {
  options.${namespace}.programs.tools.starship = {
    enable = mkEnableOption "starship";
  };

  config = mkIf cfg.enable {
    programs.starship = {
      enable  = true;
      package = pkgs.starship;
      presets = [ "nerd-font-symbols" "jetpack" ];
    };
  };
}
