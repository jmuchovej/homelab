{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  ...
}:
let
  inherit (lib) types mkIf mkEnableOption mkOption;
  inherit (inputs) nixpkgs;

  cfg = config.${namespace}.system.fonts;

  default-fonts = (with pkgs; [
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
  ]);
in
{
  options.${namespace}.system.fonts = with types; {
    enable = mkEnableOption "fonts";
    fonts = mkOption {
      type = listOf package;
      default = default-fonts;
      description = "Custom fonts to install.";
    };
    default = mkOption {
      type = str;
      default = "MonaspiceNe Nerd Font";
      description = "Default font name";
    };
  };

  config = mkIf cfg.enable {
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
