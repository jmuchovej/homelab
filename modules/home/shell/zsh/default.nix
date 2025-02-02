{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.shell.zsh;
in {
  options.${namespace}.shell.zsh = {
    enable = mkEnableOption "`zsh`";
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      package = pkgs.zsh;

      autocd = true;
      autosuggestion.enable = true;
      historySubstringSearch.enable = true;
      enableCompletion = true;

      dotDir = ".config/zsh";

      # Disable /etc/{zshrc,zprofile} that contains the "sane-default" setup out of the box
      # in order avoid issues with incorrect precedence to our own zshrc.
      # See `/etc/zshrc` for more info.
      envExtra = mkIf pkgs.stdenv.isLinux ''
        setopt no_global_rcs
      '';

      initExtra = ''
        bindkey '^[[A' history-substring-search-up # or '\eOA'
        bindkey '^[[B' history-substring-search-down # or '\eOB'
        bindkey -M vicmd 'k' history-substring-search-up
        bindkey -M vicmd 'j' history-substring-search-down
        HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
      '';

      history = {
        # share history between different zsh sessions
        share = true;

        # avoid cluttering $HOME with the histfile
        path = "${config.xdg.dataHome}/zsh/zsh_history";

        # saves timestamps to the histfile
        extended = true;

        # optimize size of the histfile by avoiding duplicates
        # or commands we don't need remembered
        save = 100000;
        size = 100000;
        expireDuplicatesFirst = true;
        ignoreDups = true;
        ignoreSpace = true;
      };

      sessionVariables = {
        LC_ALL = "en_US.UTF-8";
        KEYTIMEOUT = 0;
      };

      antidote = {
        enable = true;
        useFriendlyNames = true;
        plugins = [
          "jeffreytse/zsh-vi-mode"
          "zdharma-continuum/fast-syntax-highlighting"
          "zsh-users/zsh-completions"
          "zsh-users/zsh-autosuggestions"
          "zsh-users/zsh-history-substring-search"
          "hlissner/zsh-autopair"
          # oh-my-zsh! plugins
          "getantidote/use-omz"
          "ohmyzsh/ohmyzsh path:plugins/git"
          "ohmyzsh/ohmyzsh path:plugins/fzf"
          # "ohmyzsh/ohmyzsh path:plugins/docker"
          "ohmyzsh/ohmyzsh path:plugins/gh"
          "ohmyzsh/ohmyzsh path:plugins/gitignore"
          "ohmyzsh/ohmyzsh path:plugins/lol"
        ];
      };
    };

    home.packages = with pkgs; [
      nix-zsh-completions
      zsh-history-substring-search
    ];
  };
}
