[
  # https://zed.dev/docs/configuring-zed#auto-indent
  { auto_indent = true; }
  # https://zed.dev/docs/configuring-zed#auto-indent-on-paste
  { auto_indent_on_paste = true; }
  # https://zed.dev/docs/configuring-zed#autosave
  { autosave = "on_focus_change"; }
  # https://zed.dev/docs/configuring-zed#auto-signature-help
  {
    auto_signature_help = false;
    show_signature_help_after_edits = false;
  }
  # https://zed.dev/docs/configuring-zed#auto-update
  { auto_update = false; }
  # https://zed.dev/docs/configuring-zed#base-keymap
  { base_keymap = "VSCode"; }
  # https://zed.dev/docs/configuring-zed#close-on-file-delete
  { close_on_file_delete = false; }
  # https://zed.dev/docs/configuring-zed#confirm-quit
  { confirm_quit = false; }
  # https://zed.dev/docs/configuring-zed#diagnostics-max-severity
  { diagnostics_max_severity = null; }
  # https://zed.dev/docs/configuring-zed#direnv-integration
  { load_direnv = "shell_hook"; }
  # https://zed.dev/docs/configuring-zed#double-click-in-multibuffer
  { double_click_in_multibuffer = "select"; }
  # https://zed.dev/docs/configuring-zed#drop-target-size
  { drop_target_size = 0.2; }
  # https://zed.dev/docs/configuring-zed#ensure-final-newline-on-save
  { ensure_final_newline_on_save = true; }
  # https://zed.dev/docs/configuring-zed#extend-comment-on-newline
  { extend_comment_on_newline = true; }
  # https://zed.dev/docs/configuring-zed#edit-prediction-provider
  { features.edit_prediction_provider = "zed"; }
  # https://zed.dev/docs/configuring-zed#format-on-save
  { format_on_save = "on"; }
  {
    # https://zed.dev/docs/configuring-zed#auto-close
    use_autoclose = true;
    # https://zed.dev/docs/configuring-zed#always-treat-brackets-as-autoclosed
    always_treat_brackets_as_autoclosed = true;
    # https://zed.dev/docs/configuring-zed#jsx-tag-auto-close
    jsx_tag_auto_close.enabled = true;
  }
  {
    # https://zed.dev/docs/configuring-zed#hard-tabs
    hard_tabs = false;
    # https://zed.dev/docs/configuring-zed#tab-size
    tab_size = 2; # fight me ;p
  }
  # https://zed.dev/docs/configuring-zed#restore-on-startup
  { restore_on_startup = "last_session"; }
  # https://zed.dev/docs/configuring-zed#colorize-brackets
  { colorize_brackets = true; }
  # https://zed.dev/docs/configuring-zed#unnecessary-code-fade
  { unnecessary_code_fade = 0.3; }
]
