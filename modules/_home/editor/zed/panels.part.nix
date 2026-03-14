{ lib, ... }:
{
  settings = lib.mkMerge [
    # Project Panel
    # https://zed.dev/docs/visual-customization#project-panel
    {
      project_panel = {
        auto_fold_dirs = true;
        hide_root = true;
        hide_gitignore = false;
        hide_hidden = false;
        auto_reveal_entries = true;
        button = true;
        default_width = 240;
        dock = "left";
        sticky_scroll = true;
        sort_mode = "directories_first";
        entry_spacing = "comfortable";
        file_icons = true;
        git_status = true;
        indent_guides.show = "always";
        indent_size = 20;
        scrollbar.show = null;
      };
    }

    # Other Panels
    # https://zed.dev/docs/visual-customization#other-panels
    {
      ## Outline Panel
      outline_panel = {
        auto_fold_dirs = true;
        auto_reveal_entries = true;
        button = true;
        default_width = 240;
        dock = "left";
        file_icons = true;
        git_status = true;
        indent_guides.show = "always";
        indent_size = 20;
        scrollbar.show = "system";
      };

      ## Git Panel
      git_panel = {
        button = true;
        dock = "left";
        default_width = 360;
        status_style = "icon";
        # Sort by path (false) or status (true)
        sort_by_path = false;
        scrollbar.show = "system";
      };

      ## Debugger Panel
      debugger = {
        dock = "bottom";
        button = true;
      };
    }

    # Terminal
    # https://zed.dev/docs/visual-customization#terminal-panel
    {
      terminal = {
        #! Don't set font attributes since it follows the buffer!
        blinking = "terminal_controlled";
        button = true;
        #! Since using `devenv.sh`, let `direnv` handle activation
        detect_venv = "off";
        dock = "bottom";
        option_as_meta = false;
        toolbar.breadcrumbs = true;
        working_directory = "current_project_directory";
      };
    }

    # File Finder
    # https://zed.dev/docs/visual-customization#file-finder
    {
      file_finder = {
        file_icons = true;
        git_status = true;
        include_ignored = "smart";
      };
    }

    # Collaboration Panels
    # https://zed.dev/docs/visual-customization#collaboration-panels
    {
      ## Collaboration Panel
      collaboration_panel = {
        button = true;
        dock = "left";
        default_width = 240;
      };
      show_call_status_icon = true;

      ## Notification Panel

      notification_panel = {
        # Whether to show the notification panel button in the status bar.
        button = true;
        # Where to dock the notification panel. Can be 'left' or 'right'.
        dock = "right";
        # Default width of the notification panel.
        default_width = 380;
      };
    }
  ];
}
