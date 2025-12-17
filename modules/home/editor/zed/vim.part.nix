[
  { vim_mode = true; }
  # Vim settings for Zed
  # https://zed.dev/docs/vim
  {
    # https://zed.dev/docs/vim#changing-vim-mode-settings
    vim = {
      default_mode = "normal";
      highlight_on_yank_duration = 420;
      toggle_relative_line_numbers = true;
      use_smartcase_find = true;
      use_system_clipboard = "on_yank";
    };
  }
  {
    command_aliases = {
      W = "w";
      Wq = "wq";
      Q = "q";
    };
  }
]
