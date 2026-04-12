_: {
  rbn.programs._.terminal._.fzf.homeManager = {
    programs.fzf = {
      enable = true;

      defaultCommand = "fd --type=f --hidden --exclude=.git";
      defaultOptions = [
        "--layout=reverse"
        "--exact"
        "--bind=alt-p:toggle-preview,alt-a:select-all"
        "--multi"
        "--no-mouse"
        "--info=inline"

        "--ansi"
        "--with-nth=1.."
        "--pointer=' '"
        "--pointer=' '"
        "--header-first"
        "--border=rounded"
      ];

      tmux = {
        enableShellIntegration = true;
      };
    };
  };
}
