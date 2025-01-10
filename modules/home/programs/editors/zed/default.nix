{
  pkgs,
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (builtins) concatStringsSep;

  cfg = config.${namespace}.programs.editors.zed;

  # desired-fonts = ["MonoLisa" "JetBrainsMono Nerd Font" "JetBrainsMono" "Fira Code" "monospace"];
  # https://github.com/microsoft/vscode/issues/84018#issuecomment-550176878
  font-ligature-map = {
    #! Retrieved from: https://monaspace.githubnext.com/#code-ligatures
    "MonaSpice" = ["calt" "ss01" "ss02" "ss03" "ss04" "ss05" "ss06" "ss07" "ss08" "ss09" "liga"];
    #! Painfully determined via: https://www.monolisa.dev/playground
    "MonaLisaNerdFont" = ["ss04" "zero" "ss11" "ss13" "ss15" "ss16" "ss17"];
    "JetBrainsMonoNerdFont" = [];
    "FireCodeNerdFont" = [];
  };
  ligatures = font-ligature-map."MonaSpice";
  ligatures-str = concatStringsSep ", " (map (s: "'${s}'") ligatures);
  desired-fonts = ["MonaSpiceNe Nerd Font"];
  desired-fonts-str = concatStringsSep ", " desired-fonts;
in {
  options.${namespace}.programs.editors.zed = {
    enable = mkEnableOption "Zed";
    default = mkEnableOption "Zed as the default $EDTIOR";
  };

  config = mkIf cfg.enable {
    #! This is just to ensure we have the formatters!
    home.packages = (with pkgs; [
      biome yamlfmt taplo
    ]);

    home.sessionVariables = {
      EDITOR = mkIf cfg.default "zed --wait";
    };

    home.shellAliases = {
      "zed" = "zeditor";
    };

    programs.zed-editor = {
      enable = config.${namespace}.suites.desktop.enable;
      package = pkgs.zed-editor;
      extensions = [
        "catppuccin"
        "catppuccin-blur"
        "xml"
        "yaml"
        "toml"
        "rainbow-csv"
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
        autosave = "on_focus_change";
        restore_on_startup = "last_session";
        base_keymap = "VSCode";

        vim_mode = true;
        relative_line_numbers = true;
        vim = {
          toggle_relative_line_numbers = true;
          use_system_clipboard = "on_yank";
          use_smartcase_find = true;
          highlight_on_yank_duration = 420;
        };
        tab_size = 2; # fight me ;p

        buffer_font_family    = "MonaspiceNe Nerd Font";
        buffer_font_size      = 14;
        buffer_font_weight    = 500;
        buffer_font_features  = {
          calt = true;
          ss01 = true; ss02 = true; ss03 = true;
          ss04 = true; ss05 = true; ss06 = true;
          ss07 = true; ss08 = true; ss09 = true;
          liga = true;
        };
        terminal = {
          blinking = "terminal_controlled";
          button = true;
        };

        wrap_guides       = [ 80 90 120 ];
        show_wrap_guides  = true;

        ui_font_family    = "Brandon Text";
        ui_font_features  = {};
        ui_font_size      = 16;
        ui_font_weight    = 500;

        load_direnv = "direct";

        file_icons = true;
        git_status = true;

        toolbar = {
          breadcrumbs = true;
          quick_actions = true;
        };

        theme = {
          mode = "system";
          light = "Catppuccin Latte";
          dark = "Catppuccin Macchiato";
        };

        indent_guides = {
          show = "always";
        };

        languages = {
          YAML = {
            tab_size = 2;
            formatter = "yamlfmt";
          };
          TOML = {
             tab_size = 2;
             formatter = "taplo";
          };
          JSON = {
            tab_size = 2;
            formatter = "biome";
          };
          JSONC = {
            tab_size = 2;
            formatter = "biome";
          };
        };
        lsp = {
          biome = {
           settings = {};
          };
        };
      };
    };
  };
}
