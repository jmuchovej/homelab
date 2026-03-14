{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "system.fonts";
  imports = [ (lib.rebellion.fs.get-file "modules/_common/system/fonts.part.nix") ];
  config =
    { config, lib, ... }:
    let
      brew = config.rebellion.homebrew;
    in
    {
      system.defaults = {
        NSGlobalDomain = {
          AppleFontSmoothing = 1;
        };
      };

      homebrew = lib.mkIf brew.enable {
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
