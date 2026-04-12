_: {
  rbn.programs._.terminal._.zellij.homeManager =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (pkgs.stdenv) isLinux isDarwin;

      zns = "zellij -s $(basename $(pwd)) -l dev options --default-cwd $(pwd)";
      zas = "zellij a $(basename $(pwd))";
      zo = ''
        session_name=$(basename "$(pwd)")

        zellij --layout dev  attach --create "$session_name" options --default-cwd "$(pwd)"
      '';
    in
    {
      programs.bash.shellAliases = {
        inherit zns zas zo;
      };

      programs.zsh.shellAliases = {
        inherit zns zas zo;
      };

      programs.zellij = {
        enable = true;

        settings = {
          layout_dir = "${./_zellij/layouts}";

          copy_command =
            if isLinux then
              "wl-copy"
            else if isDarwin then
              "pbcopy"
            else
              "";

          auto_layouts = true;

          default_layout = "system";
          default_mode = "locked";
          support_kitty_keyboard_protocol = false;

          on_force_close = "quit";
          pane_frames = true;
          pane_viewport_serialization = true;
          scrollback_lines_to_serialize = 1000;
          session_serialization = true;

          ui.pane_frames = {
            rounded_corners = true;
            hide_session_name = true;
          };

          plugins = {
            tab-bar.path = "tab-bar";
            status-bar.path = "status-bar";
            strider.path = "strider";
            compact-bar.path = "compact-bar";
          };

          theme = "catppuccin-macchiato";
        };
      };

      programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
        extensions = [ "kdl" ];
      };
    };
}
