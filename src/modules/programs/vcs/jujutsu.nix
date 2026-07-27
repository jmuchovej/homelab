{
  rbn.programs._.vcs._.jujutsu.homeManager = { config, pkgs, ... }: {
    home.packages = [ pkgs.lazyjj ];

    programs.jujutsu = {
      enable = true;
      package = pkgs.jujutsu;

      settings = {
        user = with config.programs.git.settings; {
          name = user.name or "John Muchovej";
          email = user.email or "jmuchovej@users.noreply.github.com";
        };

        git = {
          private-commits = "description('wip:*') | description('private:*')";
        };

        "--scope" = [
          {
            "--when".commands = [ "status" ];
            ui.paginate = "never";
          }
        ];

        remotes = {
          origin = {
            auto-track-bookmarks = "*";
          };
          upstream = {
            auto-track-bookmarks = "*";
          };
        };

        ui = {
          color = "always";
          default-command = "log";
        };

        fix.tools.treefmt = {
          enabled = true;
          command = [
            "treefmt"
            "--no-cache"
            "--stdin"
            "$path"
          ];
          patterns = [ "glob:**/*" ];
        };

        template-aliases = {
          "format_timestamp(timestamp)" = "timestamp.ago()";
        };
      };
    };
  };
}
