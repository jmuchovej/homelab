{ inputs, ... }:
{
  flake-file.inputs.oh-my-tmux = {
    flake = false;
    url = "github:gpakosz/.tmux";
  };

  rbn.programs._.terminal._.tmux = {
    hm =
      { pkgs, lib, ... }:
      let
        inherit (lib) concatStringsSep mapAttrsToList;

        plugins = with pkgs.tmuxPlugins; [
          resurrect
          continuum
          tmux-fzf
        ];

        resurrect-processes = [
          "ssh"
          "lazygit"
          "lazyjj"
          "yazi"
          "claude"
        ];

        engine-knobs = {
          tmux_conf_24b_colour = true;
          tmux_conf_new_pane_retain_current_path = true;
          tmux_conf_copy_to_os_clipboard = true;
          tmux_conf_theme_clock_style = "24";
          # nix owns plugins (plugins.conf below); the engine must never touch TPM
          tmux_conf_update_plugins_on_launch = false;
          tmux_conf_update_plugins_on_reload = false;
        };

        options = {
          "-g" = {
            prefix = "`";
            mouse = "on";
            mode-keys = "vi";
            aggressive-resize = "on";
            allow-passthrough = "on";

            "@resurrect-strategy-vim" = "'session'";
            "@resurrect-strategy-nvim" = "'session'";
            "@resurrect-capture-pane-contents" = "'on'";
            "@resurrect-processes" = "'${concatStringsSep " " resurrect-processes}'";
            "@resurrect-dir" = "'~/.tmux/resurrect'";
            "@continuum-restore" = "'on'";
            "@continuum-save-interval" = "'10'"; # minutes
          };
          "-s" = {
            escape-time = "0";
            # forward extended keys to panes whose apps request them
            extended-keys = "on";
          };
          # RGB = direct color; extkeys = extended-keys protocol;
          "-as".terminal-features = "'*xterm*:RGB:extkeys'";
          "-ga".update-environment = [
            "TERM"
            "TERM_PROGRAM"
          ];
        };

        binds = [
          # vi-style copy mode
          "-T copy-mode-vi v send-keys -X begin-selection"
          "-T copy-mode-vi y send-keys -X copy-selection-and-cancel"
          "-T copy-mode-vi Escape send-keys -X cancel"
          "-T copy-mode-vi C-v send-keys -X rectangle-toggle"
          # splits keep the current pane's path
          "'\"' split-window -v -c '#{pane_current_path}'"
          "'%' split-window -h -c '#{pane_current_path}'"
        ];

        important = [
          ''set -ga status-right "#(${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh)"''
        ];

        render-knob = n: v: "${n}=${if builtins.isBool v then lib.boolToString v else ''"${v}"''}";
        render-sets =
          flag: attrs: mapAttrsToList (n: v: map (val: "set ${flag} ${n} ${val}") (lib.toList v)) attrs;

        local-text = concatStringsSep "\n" (
          lib.flatten [
            "# Generated from tmux.nix — edit the attrsets there, not this file."
            "# Engine phases: these lines run before _apply_theme; '#!important'"
            "# set/bind/unbind lines are re-applied last (_apply_important)."
            ""
            (mapAttrsToList render-knob engine-knobs)
            ""
            (mapAttrsToList render-sets options)
            ""
            (map (b: "bind ${b}") binds)
            ""
            (map (p: "run-shell ${p.rtp}") plugins)
            (map (l: "${l} #!important") important)
          ]
        );
      in
      {
        home.packages = [ pkgs.tmux ];

        # programs.tmux is intentionally unused because we would end up fighting
        # for ownership of tmux/tmux.conf.
        xdg.configFile = {
          "tmux/tmux.conf".source = "${inputs.oh-my-tmux}/.tmux.conf";
          "tmux/tmux.conf.local".text = local-text;
        };
      };
  };
}
