_: {
  rbn.programs._.vcs._.jujutsu.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.lazyjj ];

      programs.jujutsu = {
        enable = true;
        package = pkgs.jujutsu;

        settings = {
          user = {
            name = config.programs.git.settings.user.name or "John Muchovej";
            email = config.programs.git.settings.user.email or "jmuchovej@users.noreply.github.com";
          };

          init.default_branch = "main";
          lfs.enable = true;

          signing = {
            backend = "ssh";
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";
            sign-all = true;
          };

          git = {
            fetch.prune = true;
            sign-on-push = true;
            private-commits = "description('wip:*') | description('private:*')";
          };

          push = {
            autoSetupRemote = true;
            default = "current";
          };

          rebase.auto_stash = true;

          ui = {
            color = "always";
            default-command = "log";
          };
        };
      };
    };
}
