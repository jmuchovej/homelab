{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.desktop.onepassword;
  brew = config.rebellion.homebrew;
in
{
  options.rebellion.desktop.onepassword = {
    enable = mkEnableOption "1password";
  };

  config = mkIf cfg.enable {
    homebrew = mkIf brew.enable {
      # TODO contrib support for 1Password via Nix
      casks = [ "1password" ];

      masApps = mkIf brew.mas.enable {
        "1Password for Safari" = 1569813296;
      };
    };
  };
}
