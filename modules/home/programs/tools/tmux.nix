{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.tmux";
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (builtins) concatStringsSep map;
      inherit (lib.strings) fileContents;
      inherit (lib.rebellion.fs) get-file;

      config-files = [
        (get-file ./general.tmux)
      ];

      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-vim 'session'
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
            set -g @resurrect-processes 'ssh lazygit yazi'
            set -g @resurrect-dir '~/.tmux/resurrect'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
          '';
        }
        { plugin = tmux-fzf; }
        # { plugin = vim-tmux-navigator; }
      ];
    in
    {
      programs.tmux = {
        enable = true;
        aggressiveResize = true;
        baseIndex = 1;
        clock24 = true;
        escapeTime = 0;
        historyLimit = 2000;
        keyMode = "vi";
        mouse = true;
        newSession = true;
        prefix = "`";
        sensibleOnTop = true;
        terminal = "xterm-256color";
        extraConfig = concatStringsSep "\n" (map fileContents config-files);

        inherit plugins;
      };
    };
}
