# Imported by platform-specific system/fonts.nix modules.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rebellion.system.fonts;

  default-fonts = with pkgs; [
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
  ];
in
{
  options.rebellion.system.fonts = {
    fonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = default-fonts;
      description = "Custom fonts to install.";
    };
    default = lib.mkOption {
      type = lib.types.str;
      default = "MonaspiceNe Nerd Font";
      description = "Default font name";
    };
  };

  config = {
    nixpkgs.config.input-fonts.acceptLicense = true;

    environment.variables = {
      # Enable icons in tooling since we have nerdfonts.
      LOG_ICONS = "true";
    };

    fonts = {
      packages = cfg.fonts;
    };
  };
}
