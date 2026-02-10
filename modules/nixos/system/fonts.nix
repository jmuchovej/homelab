{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mapAttrs
    types
    ;

  cfg = config.rebellion.system.fonts;
in
{
  options.rebellion.system.fonts = with types; {
    enable = mkEnableOption "manage fonts";
    fonts = mkOption {
      type = listOf package;
      default = [ ];
      description = "Custom font packages to install.";
    };
  };

  config = mkIf cfg.enable {
    environment.variables = {
      # Enable icons in tooling since we have nerdfonts.
      LOG_ICONS = "true";
    };

    environment.systemPackages = with pkgs; [ font-manager ];

    fonts = {
      enableDefaultPackages = true;
      packages =
        with pkgs;
        [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          noto-fonts-emoji
          nerd-fonts.jetbrains-mono
        ]
        ++ cfg.fonts;

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
          mapAttrs (_: fonts: fonts ++ common) {
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
}
