{
  rbn.shells._.zsh = {
    os = { pkgs, ... }: {
      environment.shells = [ pkgs.zsh ];
    };

    hm-linux = _: {
      programs.zsh.envExtra = ''
        # setopt no_global_rcs
      '';
    };

    hm = { config, ... }: {
      home.shell.enableZshIntegration = true;
      programs.zsh = {
        enable = true;

        # zprof.enable = true;

        autocd = true;
        enableCompletion = true;
        defaultKeymap = "vicmd";

        dotDir = "${config.xdg.configHome}/zsh";

        initContent = ''
          bindkey '^[[A' history-substring-search-up # or '\eOA'
          bindkey '^[[B' history-substring-search-down # or '\eOB'
          bindkey -M vicmd 'k' history-substring-search-up
          bindkey -M vicmd 'j' history-substring-search-down
          HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
        '';

        history = {
          share = true;
          path = "${config.xdg.dataHome}/zsh/zsh_history";
          extended = true;
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
            "romkatv/zsh-defer"
            "jeffreytse/zsh-vi-mode"
            "zdharma-continuum/fast-syntax-highlighting kind:defer"
            "zsh-users/zsh-completions kind:defer"
            "zsh-users/zsh-autosuggestions kind:defer"
            "zsh-users/zsh-history-substring-search kind:defer"
            "hlissner/zsh-autopair"
            "getantidote/use-omz"
            "ohmyzsh/ohmyzsh path:plugins/git"
            "ohmyzsh/ohmyzsh path:plugins/jj"
            "ohmyzsh/ohmyzsh path:plugins/fzf"
            "ohmyzsh/ohmyzsh path:plugins/gh"
            "ohmyzsh/ohmyzsh path:plugins/gitignore"
            "ohmyzsh/ohmyzsh path:plugins/lol"
          ];
        };
      };
    };
  };
}
