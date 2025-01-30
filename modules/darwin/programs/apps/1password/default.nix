{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.apps.onepassword;
  brew = config.${namespace}.homebrew;
in {
  options.${namespace}.programs.apps.onepassword = {
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
