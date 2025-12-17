let
  ui_font_family = "Brandon Text";
  buffer_font_family = "Monaspace Neon NF";

  # desired-fonts = ["MonoLisa" "JetBrainsMono Nerd Font" "JetBrainsMono" "Fira Code" "monospace"];
  # https://github.com/microsoft/vscode/issues/84018#issuecomment-550176878
  #! Retrieved from: https://monaspace.githubnext.com/#code-ligatures
  monaspace-liguage-map = {
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
  font-ligature-map = {
    "Monaspace" = monaspace-liguage-map;
    "Monaspace Neon NF" = monaspace-liguage-map;
    "MonaSpice" = monaspace-liguage-map;
    "MonaSpiceNe Nerd Font" = monaspace-liguage-map;
    #! Painfully determined via: https://www.monolisa.dev/playground
    "MonaLisaNerdFont" = {
      ss04 = true;
      zero = true;
      ss11 = true;
      ss13 = true;
      ss15 = true;
      ss16 = true;
      ss17 = true;
    };
    "JetBrainsMonoNerdFont" = { };
    "FireCodeNerdFont" = { };
    "Brandon Text" = { };
  };
in
[
  {
    # Font Settings
    # https:#zed.dev/docs/visual-customization#fonts
    # UI Font. Use ".SystemUIFont" to use the default system font (SF Pro on macOS);
    # or ".ZedSans" for the bundled default (currently IBM Plex)
    inherit ui_font_family;
    # Font weight in standard CSS units from 100 to 900.
    ui_font_weight = 500;
    ui_font_size = 16;
    # https://zed.dev/docs/visual-customization#font-ligatures
    ui_font_features = font-ligature-map.${ui_font_family};

    # Buffer Font - Used by editor buffers
    # use ".ZedMono" for the bundled default monospace (currently Lilex)
    # Font name for editor buffers
    inherit buffer_font_family;
    # Font size for editor buffers
    buffer_font_size = 14;
    # Font weight in CSS units [100-900]
    buffer_font_weight = 500;
    # Line height "comfortable" (1.618); "standard" (1.3) or custom: `{ custom = 2 }`
    buffer_line_height = "comfortable";
    # https://zed.dev/docs/visual-customization#font-ligatures
    buffer_font_features = font-ligature-map.${buffer_font_family};

    # Terminal Font Settings
    terminal = {
      #! Don't set font attributes since it follows the buffer!
      line_height = "standard";
    };

    # Controls the font size for agent responses in the agent panel.
    # If not specified; it falls back to the UI font size.
    agent_ui_font_size = 15;
    # Controls the font size for the agent panel's message editor; user message;
    # and any other snippet of code.
    agent_buffer_font_size = 12;
  }

  # Status Bar
  # https://zed.dev/docs/visual-customization#status-bar
  {
    # Whether to show full labels in line indicator or short ones
    #   - `short`: "2 s; 15 l; 32 c"
    #   - `long`: "2 selections; 15 lines; 32 characters"
    line_indicator_format = "long";

    # Individual status bar icons can be hidden:
    # project_panel = { button = false; };
    # outline_panel = { button = false; };
    # collaboration_panel = { button = false; };
    # git_panel = { button = false; };
    # notification_panel = { button = false; };
    # agent = { button = false; };
    # debugger = { button = false; };
    # diagnostics = { button = false; };
    # search = { button = false; };
  }

  # https://zed.dev/docs/visual-customization#titlebar
  # Control which items are shown/hidden in the title bar
  {
    title_bar = {
      # Show/hide branch icon beside branch switcher
      show_branch_icon = false;
      # Show/hide branch name
      show_branch_name = true;
      # Show/hide project host and name
      show_project_items = true;
      # Show/hide onboarding banners
      show_onboarding_banner = true;
      # Show/hide user avatar
      show_user_picture = true;
      # Show/hide app user button
      show_user_menu = true;
      # Show/hide sign-in button
      show_sign_in = true;
      # Show/hide menus
      show_menus = false;
    };
  }
]
