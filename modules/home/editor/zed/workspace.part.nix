[
  {
    # Workspace Settings
    # https://zed.dev/docs/visual-customization#workspace

    # Force usage of Zed build in path prompts (file and directory pickers)
    # instead of OS native pickers (false).
    use_system_path_prompts = true;
    # Force usage of Zed built in confirmation prompts ("Do you want to save?")
    # instead of OS native prompts (false). On linux this is ignored (always false).
    use_system_prompts = true;

    # Active pane styling settings.
    active_pane_modifiers = {
      # Inset border size of the active pane; in pixels.
      border_size = 1.0;
      # Opacity of the inactive panes. 0 means transparent; 1 means opaque.
      inactive_opacity = 0.9;
    };

    # Layout mode of the bottom dock: contained; full; left_aligned; right_aligned
    bottom_dock_layout = "contained";

    # Whether to resize all the panels in a dock when resizing the dock.
    # Can be a combination of "left"; "right" and "bottom".
    resize_all_panels_in_dock = [ "left" ];
  }
]
