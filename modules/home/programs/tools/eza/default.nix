{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkForce;

  cfg = config.${namespace}.programs.tools.eza;
in {
  options.${namespace}.programs.tools.eza = {
    enable = mkEnableOption "eza";
  };

  config = mkIf cfg.enable {
    programs.eza = {
      enable = true;
      package = pkgs.eza;

      extraOptions = [
        "--group"
        "--group-directories-first"
        "--header"
        "--hyperlink"
        "--git-ignore"
      ];

      # TODO does this work on linux-arm64 yet?
      git    = true;
      icons  = "auto";
      colors = "auto";
    };

    home.shellAliases = {
      # home-manager already configures `ls`, `ll`, `la`, `lt`, and `lla`
      tree = mkForce "lt";
    };
  };
}
