{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.desktop.ghostty;
  desktop = config.rebellion.desktop;
  brew = config.rebellion.homebrew;
in
{
  options.rebellion.desktop.ghostty = {
    enable = mkEnableOption "Ghostty";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    # environment.systemPackages = [ pkgs.ghostty ];
    homebrew = mkIf (brew.enable) {
      casks = [ "ghostty" ];
    };
  };
}
