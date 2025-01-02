{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.${namespace}.programs.tools.zellij;

  zns = "zellij -s $(basename $(pwd)) -l dev options --default-cwd $(pwd)";
  zas = "zellij a $(basename $(pwd))";
  zo = ''
    session_name=$(basename "$(pwd)")

    zellij --layout dev  attach --create "$session_name" options --default-cwd "$(pwd)"
  '';
in
{
  options.${namespace}.programs.tools.zellij = {
    enable = mkEnableOption "zellij";
  };

  config = mkIf cfg.enable {
    programs.bash.shellAliases = {
      inherit zns zas zo;
    };

    programs.zsh.shellAliases = {
      inherit zns zas zo;
    };

    programs.zellij = {
      enable = true;

      settings = {
        # custom defined layouts
        layout_dir = "${./layouts}";

        # clipboard provider
        copy_command =
          if isLinux then
            "wl-copy"
          else if isDarwin then
            "pbcopy"
          else
            "";

        auto_layouts = true;

        default_layout  = "system"; # or compact
        default_mode    = "locked";
        support_kitty_keyboard_protocol = false;

        on_force_close                = "quit";
        pane_frames                   = true;
        pane_viewport_serialization   = true;
        scrollback_lines_to_serialize = 1000;
        session_serialization         = true;

        ui.pane_frames = {
          rounded_corners = true;
          hide_session_name = true;
        };

        # load internal plugins from built-in paths
        plugins = {
          tab-bar.path      = "tab-bar";
          status-bar.path   = "status-bar";
          strider.path      = "strider";
          compact-bar.path  = "compact-bar";
        };

        theme = "catppuccin-macchiato";
      };
    };

    programs.zed-editor = mkIf config.programs.zed-editor.enable {
      extensions    = [ "kdl" ];
      userSettings  = { };
    };
  };
}
