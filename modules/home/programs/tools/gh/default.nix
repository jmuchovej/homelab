{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.gh;
in {
  options.${namespace}.programs.tools.gh = {
    enable = mkEnableOption "gh";
  };

  config = mkIf cfg.enable {
    programs.gh = {
      enable = true;
      package = pkgs.gh;
      settings = {
        protocol = "ssh";
        prompt = "enabled";
        aliases = {};
      };
    };

    programs.gh-dash = {
      enable = true;
      package = pkgs.gh-dash;
      # settings = { };
    };
  };
}
