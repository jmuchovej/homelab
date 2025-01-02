{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (lib.${namespace});

  cfg = config.${namespace}.programs.tools.topgrade;
in
{
  options.${namespace}.programs.tools.topgrade = {
    enable = mkEnableOption "topgrade.";
  };

  config = mkIf cfg.enable {
    programs.topgrade = {
      enable = true;

      settings = {
        misc = {
          no_retry = true;
          display_time = true;
          skip_notify = true;
        };
        git = {
          repos = [
            "~/Documents/github/*/"
            "~/Documents/gitlab/*/"
            "~/.config/.dotfiles/"
            "~/.config/nvim/"
          ];
        };
      };
    };
  };
}
