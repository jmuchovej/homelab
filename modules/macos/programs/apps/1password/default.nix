{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.programs.apps.onepassword;
  brew = config.rebellion.homebrew;
in {
  options.rebellion.programs.apps.onepassword = {
    enable = mkEnableOption "1password";
  };

  config = mkIf (cfg.enable && brew.enable) {
    homebrew = {
      # TODO contrib support for 1Password via Nix
      casks = ["1password"];

      masApps = mkIf brew.mas.enable {
        "1Password for Safari" = 1569813296;
      };
    };
  };
}
