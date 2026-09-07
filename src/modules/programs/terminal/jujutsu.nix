{
  rbn.programs._.terminal._.jujutsu.hm = { user, pkgs, ... }: {
    home.packages = with pkgs; [
      cargo-binstall
      lazyjj
    ];

    home.shellAliases = {
      jj = "jj --color always";
    };

    programs.jujutsu = {
      enable = true;
      settings = {
        user = {
          name = user.fullname;
          inherit (user) email;
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
        snapshot.auto-update-stale = true;
        ui = {
          default-command = "log";
        };
        template-aliases = {
          "format_timestamp(timestamp)" = "timestamp.ago()";
        };
        # `rbn.assisted-by.*` are not real jj keys; agent harnesses pass them
        # per command (`--config rbn.assisted-by.tool=… --config
        # rbn.assisted-by.model=…`, injected by `ai-tools/hooks/assisted-by.nu`
        # for Claude Code) and the trailer renders `Assisted-by: <tool> (<model>)`.
        # All-or-nothing on purpose: a lone key renders nothing, not a
        # half-filled trailer.
        templates.commit_trailers = ''
          format_signed_off_by_trailer(self)
          ++ if(config("rbn.assisted-by.tool") && config("rbn.assisted-by.model"),
                "Assisted-by: " ++ config("rbn.assisted-by.tool").as_string()
                ++ " (" ++ config("rbn.assisted-by.model").as_string() ++ ")\n",
                "")
        '';
      };
    };

    programs.starship = {
      extraPackages = [ pkgs.jj-starship ];
      settings = {
        custom.jj = {
          when = "jj-starship detect";
          shell = [ "jj-starship" ];
          format = "$output";
        };
        git_branch.disabled = true;
        git_status.disabled = true;
      };
    };
  };
}
