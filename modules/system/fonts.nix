# Consolidated font configuration across NixOS and darwin.
_: {
  rbn.system._.fonts = {
    nixos =
      { lib, pkgs, ... }:
      let
        inherit (lib) mapAttrs;
      in
      {
        nixpkgs.config.input-fonts.acceptLicense = true;
        # Enable icons in tooling since we have nerdfonts.
        environment.variables.LOG_ICONS = "true";
        environment.systemPackages = [ pkgs.font-manager ];

        fonts = {
          enableDefaultPackages = true;
          packages = with pkgs; [
            # Desktop Fonts
            # input-fonts
            hack-font
            fira-code
            fira-code-symbols
            jetbrains-mono
            corefonts # MS fonts
            b612 # high legibility
            material-icons
            material-design-icons
            work-sans
            comic-neue
            source-sans
            inter
            lexend

            # Emojis
            noto-fonts-color-emoji
            twemoji-color-font

            # Nerd Fonts
            nerd-fonts.caskaydia-cove
            nerd-fonts.iosevka
            nerd-fonts.monaspace
            nerd-fonts.symbols-only
            nerd-fonts.fira-code
            nerd-fonts.jetbrains-mono

            # Noto Fonts
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-cjk-serif
            noto-fonts-color-emoji
            nerd-fonts.jetbrains-mono
          ];

          fontconfig = {
            antialias = true;
            hinting.enable = true;

            defaultFonts =
              let
                common = [
                  "MonaspiceNe Nerd Font"
                  "CaskaydiaCove Nerd Font Mono"
                  "Iosevka Nerd Font"
                  "Symbols Nerd Font"
                  "Noto Color Emoji"
                ];
              in
              mapAttrs (_: f: f ++ common) {
                serif = [ "Noto Serif" ];
                sansSerif = [ "Lexend" ];
                emoji = [ "Noto Color Emoji" ];
                monospace = [
                  "Source Code Pro Medium"
                  "Source Han Mono"
                ];
              };
          };

          fontDir = {
            enable = true;
            decompressFonts = true;
          };
        };
      };

    darwin =
      { host, lib, ... }:
      let
        brew = host.homebrew;
      in
      {
        system.defaults.NSGlobalDomain.AppleFontSmoothing = 1;

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
  };
}
