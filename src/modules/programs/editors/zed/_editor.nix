{ lib, ... }:
{
  settings = lib.mkMerge [
    # Editor Settings
    # https://zed.dev/docs/visual-customization#editor
    {
      # Whether the cursor blinks in the editor.
      cursor_blink = true;

      # Cursor shape for the default editor: bar, block, underline, hollow
      cursor_shape = "bar";

      # Highlight the current line in the editor: none; gutter; line; all
      current_line_highlight = "all";

      # When does the mouse cursor hide: never; on_typing; on_typing_and_movement
      hide_mouse = "on_typing_and_movement";

      # Whether to highlight all occurrences of the selected text in an editor.
      selection_highlight = true;
      # Whether the text selection should have rounded corners.
      rounded_selection = true;

      # Visually show tabs and spaces  (none; all; selection; boundary; trailing)
      show_whitespaces = "selection";
      whitespace_map = {
        space = "•";
        tab = "→";
      };

      unnecessary_code_fade = 0.3; # How much to fade out unused code.

      # Hide the values of in variables from visual display in private files
      redact_private_values = false;

      # Soft-wrap and rulers
      soft_wrap = "preferred_line_length"; # none; editor_width; preferred_line_length; bounded
      preferred_line_length = 88; # Column to soft-wrap
      show_wrap_guides = true; # Show/hide wrap guides (vertical rulers)
      wrap_guides = [
        80
        88
        90
        120
      ];

      # Gutter Settings
      gutter = {
        line_numbers = true; # Show/hide line numbers in the gutter.
        runnables = true; # Show/hide runnables buttons in the gutter.
        breakpoints = true; # Show/hide show breakpoints in the gutter.
        folds = true; # Show/hide show fold buttons in the gutter.
        min_line_number_digits = 4; # Reserve space for N digit line numbers
      };
      relative_line_numbers = "enabled"; # Show relative line numbers in gutter

      # Indent guides
      indent_guides = {
        enabled = true;
        # Width of guides in pixels [1-10]
        line_width = 1;
        # Width of active guide in pixels [1-10]
        active_line_width = 1;
        # disabled, fixed, indent_aware
        coloring = "indent_aware";
        # disabled, indent_aware
        background_coloring = "indent_aware";
      };

      # Whether to stick scopes to the top of the editor.
      sticky_scroll.enabled = true;
    }

    # Git Blame
    # https://zed.dev/docs/visual-customization#editor-blame
    # https://zed.dev/docs/configuring-zed#git
    {
      git = {
        git_gutter = "tracked_files";
        # Sets the debounce threshold (in milliseconds) after which changes are reflected in the git gutter.
        gutter_debounce = 100;
        hunk_style = "staged_hollow"; # staged_hollow, unstaged_hollow
        branch_picker.show_author_name = true;
        # https://zed.dev/docs/configuring-zed#inline-git-blame
        inline_blame = {
          # Show/hide inline blame
          enabled = true;
          # Show after delay (ms)
          delay_ms = 0;
          # Minimum column to inline display blame
          min_column = 80;
          # Padding between code and inline blame (em)
          padding = 6;
          # Show/hide commit summary
          show_commit_summary = true;
        };
      };
    }

    # Editor toolbar related settings
    # https://zed.dev/docs/visual-customization#editor-toolbar
    {
      toolbar = {
        breadcrumbs = true; # Whether to show breadcrumbs.
        quick_actions = true; # Whether to show quick action buttons.
        selections_menu = true; # Whether to show the Selections menu
        agent_review = true; # Whether to show agent review buttons
        code_actions = false; # Whether to show code action buttons
      };
    }

    # Scrollbar & Minimap
    # https://zed.dev/docs/visual-customization#editor-scrollbar
    {
      # Scrollbar related settings
      scrollbar = {
        # When to show the scrollbar in the editor (auto; system; always; never)
        show = "auto";
        cursors = true; # Show cursor positions in the scrollbar.
        git_diff = true; # Show git diff indicators in the scrollbar.
        search_results = true; # Show buffer search results in the scrollbar.
        selected_text = true; # Show selected text occurrences in the scrollbar.
        selected_symbol = true; # Show selected symbol occurrences in the scrollbar.
        diagnostics = "all"; # Show diagnostics (none; error; warning; information; all)
        axes = {
          horizontal = true; # Show/hide the horizontal scrollbar
          vertical = true; # Show/hide the vertical scrollbar
        };
      };

      ### Minimap
      # Minimap related settings
      minimap = {
        show = "never"; # When to show (auto; always; never)
        display_in = "active_editor"; # Where to show (active_editor; all_editor)
        thumb = "always"; # When to show thumb (always; hover)
        thumb_border = "left_open"; # Thumb border (left_open; right_open; full; none)
        max_width_columns = 80; # Maximum width of minimap
        current_line_highlight = null; # Highlight current line (null; line; gutter)
      };

      # Control Editor scroll beyond the last line: off; one_page; vertical_scroll_margin
      scroll_beyond_last_line = "one_page";
      # Lines to keep above/below the cursor when scrolling with the keyboard
      vertical_scroll_margin = 3;
      # The number of characters to keep on either side when scrolling with the mouse
      horizontal_scroll_margin = 5;
      # Scroll sensitivity multiplier
      scroll_sensitivity = 1.0;
      # Scroll sensitivity multiplier for fast scrolling (hold alt while scrolling)
      fast_scroll_sensitivity = 4.0;
    }

    # Editor Tabs
    # https://zed.dev/docs/visual-customization#editor-tabs
    {
      # Maximum number of tabs per pane. Unset for unlimited.
      max_tabs = null;

      # Customize the tab bar appearance
      tab_bar = {
        # Show/hide the tab bar
        show = true;
        # Show/hide history buttons on tab bar
        show_nav_history_buttons = false;
        # Show hide buttons (new, split, zoom)
        show_tab_bar_buttons = true;
      };

      tabs = {
        # Color to show git status
        git_status = true;
        # Close button position (left, right, hidden)
        close_position = "left";
        # Close button shown (hover, always, hidden)
        show_close_button = "always";
        # Icon showing file type
        file_icons = true;
        # Show diagnostics in file icon (off, errors, all). Requires file_icons=true
        show_diagnostics = "errors";
      };
    }

    # Editor Status Bar
    # https://zed.dev/docs/visual-customization#status-bar-1
    {
      status_bar = {
        # Show/hide a button that displays the active buffer's language.
        # Clicking the button brings up the language selector.
        # Defaults to true.
        active_language_button = true;
        # Show/hide a button that displays the cursor's position.
        # Clicking the button brings up an input for jumping to a line and column.
        # Defaults to true.
        cursor_position_button = true;
        # Show/hide a button that displays the buffer's line-ending mode.
        # Clicking the button brings up the line-ending selector.
        # Defaults to false.
        line_endings_button = false;
      };
      enable_language_server = true;
      global_lsp_settings = {
        # Show/hide the LSP button in the status bar.
        # Activity from the LSP is still shown.
        # Button is not shown if "enable_language_server" if false.
        button = true;
      };
    }

    # Multibuffer
    # https://zed.dev/docs/visual-customization#multibuffer
    {
      # The default number of lines to expand excerpts in the multibuffer by.
      expand_excerpt_lines = 5;
      # The default number of lines of context provided for excerpts in the multibuffer by.
      excerpt_context_lines = 2;
    }
    # Editor Completions; Snippets; Actions; Diagnostics
    # https://zed.dev/docs/visual-customization#editor-lsp
    {
      snippet_sort_order = "inline"; # Snippets completions: top; inline; bottom; none
      show_completions_on_input = true; # Show completions while typing
      show_completion_documentation = true; # Show documentation in completions
      auto_signature_help = false; # Show method signatures inside parentheses

      # Whether to show the signature help after completion or a bracket pair inserted.
      # If `auto_signature_help` is enabled; this setting will be treated as enabled also.
      show_signature_help_after_edits = false;

      # Whether to show code action button at start of buffer line.
      inline_code_actions = true;

      # Which level to use to filter out diagnostics displayed in the editor:
      diagnostics_max_severity = null; # off; error; warning; info; hint; null (all)

      # How to render LSP `textDocument/documentColor` colors in the editor.
      lsp_document_colors = "inlay"; # none; inlay; border; background
      # When to show the scrollbar in the completion menu.
      completion_menu_scrollbar = "never"; # auto; system; always; never
      # Turn on colorization of brackets in editors (configurable per language)
      colorize_brackets = true;
    }

    # Edit Predictions
    # https://zed.dev/docs/visual-customization#editor-ai
    {
      edit_predictions = {
        mode = "eager"; # Automatically show (eager) or hold-alt (subtle)
        enabled_in_text_threads = true; # Show/hide predictions in agent text threads
      };
      show_edit_predictions = true; # Show/hide predictions in editor
    }

    # Editor Inlay Hints
    # https://zed.dev/docs/visual-customization#editor-inlay-hints
    {
      inlay_hints = {
        enabled = false;
        # Toggle certain types of hints on and off; all switched on by default.
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;

        # Whether to show a background for inlay hints (theme `hint.background`)
        show_background = false;

        # Time to wait after editing before requesting hints (0 to disable debounce)
        edit_debounce_ms = 700;
        # Time to wait after scrolling before requesting hints (0 to disable debounce)
        scroll_debounce_ms = 50;

        # A set of modifiers which; when pressed; will toggle the visibility of inlay hints.
        toggle_on_modifiers_press = {
          control = false;
          shift = false;
          alt = false;
          platform = false;
          function = false;
        };
      };
    }
  ];
}
