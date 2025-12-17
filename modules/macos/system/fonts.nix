{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.system.fonts;
  brew = config.rebellion.homebrew;
in
{
  imports = [ (get-file "modules/common/system/fonts.nix") ];

  config = mkIf cfg.enable {
    system.defaults = {
      NSGlobalDomain = {
        AppleFontSmoothing = 1;
      };
    };

    homebrew = mkIf brew.enable {
      casks = [
        "font-jetbrains-mono"
        "font-jetbrains-mono-nerd-font"
        "font-maple-mono"
        "font-maple-mono-nf"
        "font-monaspace"
        "font-monaspace-nf"
        "font-lato"
        "font-roboto"
        "font-roboto-mono-nerd-font"
        "font-stix-two-math"
        "font-stix-two-text"
        "font-ibm-plex"
        "font-ibm-plex-mono"
        "font-ibm-plex-math"
        "font-ibm-plex-sans"
        "font-ibm-plex-serif"
        "font-red-hat-display"
        "font-red-hat-mono"
        "font-red-hat-text"
      ];
    };
  };
}
