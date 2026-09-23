{ den, ... }: {
  rbn.system._.fonts = {
    includes = [
      (den.batteries.unfree [ "corefonts" ])
    ];

    os = { pkgs, ... }: {
      fonts.packages = with pkgs; [
        rbn.fonts.brandon-text
        rbn.fonts.monolisa
        monaspace
        maple-mono.opentype

        hack-font
        fira-code-symbols
        corefonts # MS fonts
        b612 # high legibility
        material-icons
        material-design-icons
        comic-neue
        # Includes Inter, Lexend, Albert Sans, Public Sans, Lora, Work Sans, Source Sans, JetBrains Mono, Fira Code, Noto, etc.
        google-fonts

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
        nerd-fonts.zed-mono
        nerd-fonts.roboto-mono
        maple-mono.NF

        # Noto Fonts
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ];
    };

    nixos = { pkgs, ... }: {
      nixpkgs.config.input-fonts.acceptLicense = true;
      environment.variables.LOG_ICONS = "true";
      environment.systemPackages = [ pkgs.font-manager ];

      fonts = {
        enableDefaultPackages = true;

        antialiasing = true;
        hinting.enable = true;

        defaultFonts = {
          monospace = [
            "MonaspiceNe Nerd Font"
            "MonaspiceKr Nerd Font"
            "Maple Mono Nerd Font"
          ];
          serif = [ "Noto Serif" ];
          sansSerif = [
            "Albert Sans"
            "Brandon Text"
          ];
          emoji = [ "Noto Color Emoji" ];
        };

        fontDir = {
          enable = true;
          decompressFonts = true;
        };
      };
    };

    macos = _: {
      system.defaults.NSGlobalDomain.AppleFontSmoothing = 1;
    };
  };
}
