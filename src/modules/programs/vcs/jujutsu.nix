_: {
  rbn.programs._.vcs._.jujutsu.homeManager = { config, pkgs, ... }: {
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

        git = {
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
