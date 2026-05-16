_: {
  rbn.shells._.zsh.homeManager =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (pkgs.stdenv) isLinux;
    in
    {
      programs.zsh = {
        enable = true;
        package = pkgs.zsh;

        autocd = true;
        autosuggestion.enable = true;
        historySubstringSearch.enable = true;
        enableCompletion = true;

        dotDir = "${config.xdg.configHome}/zsh";

        envExtra = mkIf isLinux ''
          # setopt no_global_rcs
        '';

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
            "jeffreytse/zsh-vi-mode"
            "zdharma-continuum/fast-syntax-highlighting"
            "zsh-users/zsh-completions"
            "zsh-users/zsh-autosuggestions"
            "zsh-users/zsh-history-substring-search"
            "hlissner/zsh-autopair"
            "getantidote/use-omz"
            "ohmyzsh/ohmyzsh path:plugins/git"
            "ohmyzsh/ohmyzsh path:plugins/fzf"
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
