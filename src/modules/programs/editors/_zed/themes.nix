{ lib, ... }:
{
  extensions = [
    "catppuccin"
    "catppuccin-blur"
    "catppuccin-icons"
    "charmed-icons"
    "vscode-icons"
    "colored-zed-icons-theme"
    "jetbrains-new-ui-icons"
    "material-icon-theme"
    "nvim-nightfox"
  ];
  settings = lib.mkMerge [
    {
      # Theme Settings
      # https://zed.dev/docs/visual-customization#themes
      theme = {
        # dark = "Catppuccin Frappé";
        light = "Dawnfox - opaque";
        # light = "Catppuccin Latte";
        dark = "Carbonfox - opaque";
        mode = "system";
      };
      icon_theme = {
        # dark = "Catppuccin Frappé";
        dark = "Soft Charmed Icons";
        # light = "Catppuccin Latte";
        light = "Light Charmed Icons";
        mode = "system";
      };
    }
  ];
}
