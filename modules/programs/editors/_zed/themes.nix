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
    "flexoki-themes"
  ];
  settings = lib.mkMerge [
    {
      # Theme Settings
      # https://zed.dev/docs/visual-customization#themes
      theme = {
        # dark = "Catppuccin Frappé";
        # light = "Dawnfox - opaque";
        light = "Flexoki Light";
        # light = "Catppuccin Latte";
        dark = "Flexoki Dark";
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
