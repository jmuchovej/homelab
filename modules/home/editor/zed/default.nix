{
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkForce;
  # inherit (builtins) concatStringsSep;

  cfg = config.${namespace}.editor.zed;
  desktop = config.${namespace}.desktop;

  # desired-fonts = ["MonoLisa" "JetBrainsMono Nerd Font" "JetBrainsMono" "Fira Code" "monospace"];
  # https://github.com/microsoft/vscode/issues/84018#issuecomment-550176878
  font-ligature-map = {
    #! Retrieved from: https://monaspace.githubnext.com/#code-ligatures
    "MonaSpice" = [
      "calt"
      "ss01"
      "ss02"
      "ss03"
      "ss04"
      "ss05"
      "ss06"
      "ss07"
      "ss08"
      "ss09"
      "liga"
    ];
    #! Painfully determined via: https://www.monolisa.dev/playground
    "MonaLisaNerdFont" = [
      "ss04"
      "zero"
      "ss11"
      "ss13"
      "ss15"
      "ss16"
      "ss17"
    ];
    "JetBrainsMonoNerdFont" = [ ];
    "FireCodeNerdFont" = [ ];
  };
in
# ligatures = font-ligature-map."MonaSpice";
# ligatures-str = concatStringsSep ", " (map (s: "'${s}'") ligatures);
# desired-fonts = [ "MonaSpiceNe Nerd Font" ];
# desired-fonts-str = concatStringsSep ", " desired-fonts;
{
  options.${namespace}.editor.zed = {
    enable = mkEnableOption "Zed";
    default = mkEnableOption "Zed as the default $EDTIOR";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    home.sessionVariables.EDITOR = mkIf cfg.default (mkForce "zed --wait");

    home.shellAliases = {
      "zed" = "zeditor";
    };

    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor;
      #! This is just to ensure we have the formatters!
      extraPackages = with pkgs; [
        treefmt # Format the whole tree
        biome # Most web-tools
        yamlfmt # YAML
        jsonfmt # JSON
        taplo # TOML
      ];
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

        border_size = 1.0;
        inactive_opacity = 0.8;

        vim_mode = true;
        relative_line_numbers = true;
        vim = {
          toggle_relative_line_numbers = true;
          use_system_clipboard = "on_yank";
          use_smartcase_find = true;
          highlight_on_yank_duration = 420;
        };
        tab_size = 2; # fight me ;p
        hard_tabs = true;

        buffer_font_family = "MonaspiceNe Nerd Font";
        buffer_font_size = 14;
        buffer_font_weight = 500;
        buffer_font_features = {
          calt = true;
          ss01 = true;
          ss02 = true;
          ss03 = true;
          ss04 = true;
          ss05 = true;
          ss06 = true;
          ss07 = true;
          ss08 = true;
          ss09 = true;
          liga = true;
        };

        preferred_line_length = 88;
        wrap_guides = [
          80
          90
          120
        ];
        show_wrap_guides = true;

        tab_bar = {
          show = true;
          show_nav_history_buttons = false;
        };

        tabs = {
          close_position = "left";
          file_icons = true;
          git_status = true;
          always_show_close_button = true;
        };

        format_on_save = "on";

        ui_font_family = "Brandon Text";
        ui_font_features = { };
        ui_font_size = 16;
        ui_font_weight = 500;

        load_direnv = "shell_hook";

        file_icons = true;
        git_status = true;

        toolbar = {
          breadcrumbs = true;
          quick_actions = true;
        };

        theme = {
          mode = "system";
          light = "Catppuccin Latte";
          dark = "Catppuccin Frappé";
        };

        indent_guides = {
          enabled = true;
          show = "always";
          line_width = 1;
          active_line_width = 2;
          coloring = "indent_aware";
        };

        scrollbar = {
          show = "auto";
          cursors = true;
          git_diff = true;
          search_results = true;
          selected_symbol = true;
          diagnostics = "all";
          axes = {
            horizontal = true;
            vertical = true;
          };
        };

        project_panel = {
          button = true;
          default_width = 240;
          dock = "left";
          file_icons = true;
          git_status = true;
          entry_spacing = "comfortable";
          indent_size = 20;
          auto_reveal_entries = true;
          auto_fold_dirs = false;
          scrollbar = {
            show = null;
          };
          indent_guides = {
            show = "auto";
          };
        };

        outline_panel = {
          button = true;
          default_width = 240;
          dock = "left";
          file_icons = true;
          git_status = true;
          entry_spacing = "comfortable";
          indent_size = 20;
          auto_reveal_entries = true;
          auto_fold_dirs = false;
          scrollbar = {
            show = null;
          };
          indent_guides = {
            show = "auto";
          };
        };

        assistant_panel = {
          enabled = true;
          button = true;
          dock = "left";
          default_width = 420;
          default_height = 420;
          provider = "openai";
          version = 1;
        };

        calls = {
          mute_on_join = true;
          share_on_join = false;
        };

        journal = {
          hour_format = "hour24";
        };

        terminal = {
          #! Don't set font attributes since it follows the buffer!
          blinking = "terminal_controlled";
          button = true;
          working_directory = "current_project_directory";

          dock = "bottom";
          option_as_meta = false;

          #! Since using `devenv.sh`, let `direnv` handle activation
          detect_venv = "off";
          toolbar = {
            breadcrumbs = true;
          };
        };

        git = {
          git_gutter = "tracked_files";
          inline_blame = {
            enabled = true;
            show_commit_summary = true;
            min_column = 88;
          };
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
            settings = { };
          };
        };

        file_types = {
          "Shell" = [ ".envrc*" ];
        };

        use_autoclose = true;
        always_treat_brackets_as_autoclosed = true;

        file_scan_exclusions = [
          "**/.git"
          "**/.svn"
          "**/.hg"
          "**/.jj"
          "**/CVS"
          "**/.DS_Store"
          "**/Thumbs.db"
          "**/.classpath"
          "**/.settings"
          "**/.sync-conflict*"
          "**/*.sync-conflict*"
        ];
      };
    };
  };
}
