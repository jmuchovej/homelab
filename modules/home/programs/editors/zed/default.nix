{ pkgs, lib, config, namespace, ... }: let
  inherit (lib) mkEnableOption mkIf;
  inherit (builtins) concatStringsSep;

  cfg = config.${namespace}.programs.editors.zed;

  # desired-fonts = ["MonoLisa" "JetBrainsMono Nerd Font" "JetBrainsMono" "Fira Code" "monospace"];
  # https://github.com/microsoft/vscode/issues/84018#issuecomment-550176878
  font-ligature-map = {
    #! Retrieved from: https://monaspace.githubnext.com/#code-ligatures
    "MonaSpice" = [ "calt" "ss01" "ss02" "ss03" "ss04" "ss05" "ss06" "ss07" "ss08" "ss09" "liga" ];
    #! Painfully determined via: https://www.monolisa.dev/playground
    "MonaLisaNerdFont" = [ "ss04" "zero" "ss11" "ss13" "ss15" "ss16" "ss17" ];
    "JetBrainsMonoNerdFont" = [ ];
    "FireCodeNerdFont" = [ ];
  };
  ligatures = font-ligature-map."MonaSpice";
  ligatures-str = concatStringsSep ", " (map (s: "'${s}'") ligatures);
  desired-fonts = ["MonaSpiceNe Nerd Font"];
  desired-fonts-str = concatStringsSep ", " desired-fonts;
in {
  options.${namespace}.programs.editors.zed = {
    enable  = mkEnableOption "Zed";
    default = mkEnableOption "Zed as default $EDTIOR";
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable      = config.${namespace}.suites.desktop.enable;
      package     = pkgs.zed-editor;
      # https://raw.githubusercontent.com/nix-community/nix-vscode-extensions/master/data/cache/open-vsx-latest.json
      extensions  = [
        "catppuccin" "catppuccin-blur"
        "xml" "yaml" "toml" "rainbow-csv"
        "justfile"
        "env" # mkhl.direnv mikestead.dotenv
        # gruntfuggly.todo-tree
        # vscode-icons-team.vscode-icons
        # edwinhuish.better-comments-next
        # tomoki1207.pdf
        # signageos.signageos-vscode-sops
      ];
      userSettings = {
        # Editor settings
        "autosave"              = "on_focus_change";
        "restore_on_startup"    = "last_session";
        "base_keymap"           = "VScode";
        "vim_mode"              = true;

        "buffer_font_family"    = "MonaSpiceNe Nerd Font";
        "buffer_font_features"  = {
          "calt" = true;
          "ss01" = true; "ss02" = true; "ss03" = true;
          "ss04" = true; "ss05" = true; "ss06" = true;
          "ss07" = true; "ss08" = true; "ss09" = true;
          "liga" = true;
        };

        "load_direnv" = "direct";

        "file_icons" = true;
        "git_status" = true;

        "toolbar" = {
          "breadcrumbs"   = true;
          "quick_actions" = true;
        };

        "theme" = {
          "mode"  = "system";
          "light" = "Catppuccin Latte";
          "dark"  = "Catppuccin Macchiato";
        };

        "indent_guides" = {
          "show" = "always";
        };
      };
    };
  };
}
