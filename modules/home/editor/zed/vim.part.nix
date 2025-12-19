{ lib, ... }:
{
  settings = lib.mkMerge [
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
  ];
  keybinds = [
    # https://zed.dev/docs/vim#customizing-key-bindings
    {
      context = "VimControl && !menu";
      bindings = {
        # Put key bindings here if you want them to work in normal & visual mode.
      };
    }
    {
      context = "vim_mode == normal && !menu";
      bindings = {
        # Use neovim's yank behavior: yank to end of line.
        shift-y = [
          "workspace::SendKeystrokes"
          "y $"
        ];
      };
    }
    {
      context = "vim_mode == insert";
      bindings = {
        # In insert mode, make jk escape to normal mode.
        "j k" = "vim::NormalBefore";
      };
    }
    {
      context = "EmptyPane || SharedScreen";
      bindings = {
        # Put key bindings here (in addition to the context above) if you want them to
        # work when no editor exists.
        "space f" = "file_finder::Toggle";
      };
    }
    {
      context = "VimControl && !menu && vim_mode != operator";
      bindings = {
        "w" = "vim::NextSubwordStart";
        "b" = "vim::PreviousSubwordStart";
        "e" = "vim::NextSubwordEnd";
        "g e" = "vim::PreviousSubwordEnd";
      };
    }
  ];
}
