{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.desktop.arc;
  brew = config.rebellion.homebrew;
in
{
  options.rebellion.desktop.arc = {
    enable = mkEnableOption "Arc Browser";
  };

  config = mkIf cfg.enable {
    # environment.systemPackages = [pkgs.arc-browser];

    homebrew = mkIf brew.enable {
      casks = [ "arc" ];
    };
  };
}
