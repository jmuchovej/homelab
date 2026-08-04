{
  rbn.programs._.terminal._.topgrade = {
    hm = _: {
      programs.topgrade = {
        enable = true;

        settings = {
          misc = {
            no_retry = true;
            display_time = true;
            notify_end = "never";
            only = [
              "system"
              "git_repos"
            ];
            no_self_update = true;
          };
          linux = {
            nix_arguments = "--flake";
            nix_env_arguments = "--prebuilt-only";
            home_manager_arguments = [
              "--flake"
              "file"
            ];
          };
          git = {
            repos = [
              "~/Documents/dev/**/"
              "~/Documents/Research/*/"
              "~/Documents/Projects/*/"
              "~/.config/dotfiles/"
            ];
          };
        };
      };
    };
  };
}
