{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  namespace = "system";
  description = "manage fonts";
  imports = [ (lib.rebellion.fs.get-file "modules/_common/system/fonts.part.nix") ];
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mapAttrs;
    in
    {
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
            noto-fonts-color-emoji
            nerd-fonts.jetbrains-mono
          ]
          ++ cfg.fonts.fonts;

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
