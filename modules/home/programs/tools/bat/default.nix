{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) getExe getExe' mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.bat;

  bat-bin = getExe config.programs.bat.package;
in {
  options.${namespace}.programs.tools.bat = {
    enable = mkEnableOption "Whether or not to enable bat.";
  };

  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;

      config  = {
      };

      extraPackages = with pkgs.bat-extras; [
        batdiff
        batgrep
        batman
        batpipe
        batwatch
        prettybat
      ];
    };

    home.shellAliases = {
      cat = "bat";
    };
  };
}
