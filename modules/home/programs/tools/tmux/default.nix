{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (builtins) concatStringsSep map;
  inherit (lib) mkIf mkEnableOption;
  inherit (lib.strings) fileContents;

  cfg = config.${namespace}.programs.tools.tmux;
  configFiles = lib.snowfall.fs.get-files ./config;

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
    {plugin = tmux-fzf;}
    # { plugin = vim-tmux-navigator; }
  ];
in {
  options.${namespace}.programs.tools.tmux = {
    enable = mkEnableOption "tmux";
  };

  config = mkIf cfg.enable {
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
      extraConfig = concatStringsSep "\n" (map fileContents configFiles);

      inherit plugins;
    };
  };
}
