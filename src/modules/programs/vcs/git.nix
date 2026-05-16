_: {
  rbn.programs._.vcs._.git.homeManager = { pkgs, ... }: {
    xdg.configFile."git/ignore" = {
      enable = true;
      text = ''
        _research/
        .scratch/
        .arxiv/
      '';
    };

    home.packages = with pkgs; [
      delta
      difftastic
    ];

    programs.git-credential-oauth.enable = true;

    programs.git = {
      enable = true;

      signing.format = null;

      settings = {
        user.name = "John Muchovej";
        user.email = "jmuchovej@users.noreply.github.com";

        color.ui = true;

        pull.ff = "only";

        push = {
          default = "current";
          autoSetupRemote = true;
        };

        init.defaultBranch = "main";

        filter.lfs = {
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
          process = "git-lfs filter-process -- %f";
        };
      };
    };
  };
}
