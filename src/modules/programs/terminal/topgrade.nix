_: {
  rbn.programs._.terminal._.topgrade.homeManager = {
    programs.topgrade = {
      enable = true;

      settings = {
        misc = {
          no_retry = true;
          display_time = true;
          skip_notify = true;
        };
        git = {
          repos = [
            "~/Documents/github/*/"
            "~/Documents/gitlab/*/"
            "~/.config/dotfiles/"
            "~/.config/nvim/"
          ];
        };
      };
    };
  };
}
