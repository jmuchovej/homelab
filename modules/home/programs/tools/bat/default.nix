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
  ov-bin  = getExe' pkgs.ov "ov";
in {
  options.${namespace}.programs.tools.bat = {
    enable = mkEnableOption "Whether or not to enable bat.";
  };

  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;

      config  = {
        # https://noborus.github.io/ov/bat/index.html
        pager = "${ov-bin} -F -H3";
        wrap  = "never";
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
      cat = "${bat-bin}";
    };
  };
}
