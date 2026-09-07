{ __findFile, ... }: {
  rbn.programs._.development = {
    includes = [
      <rbn/programs/development/devenv>
      <rbn/programs/development/direnv>
      <rbn/programs/development/mise>
      <rbn/programs/development/git>
      <rbn/programs/development/github>
      <rbn/programs/development/jujutsu>
    ];

    hm = { pkgs, ... }: {
      home.packages = with pkgs; [
        pre-commit
        prek
        treefmt
        tokei
        onefetch
        act

        delta
        difftastic

        (writeShellScriptBin "closure-size" ''
          nix path-info --recursive --closure-size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')

        (writeShellScriptBin "store-size" ''
          nix path-info --recursive --size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')
      ];
    };

    _.devenv.hm =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        programs.devenv = {
          enable = true;
          package = pkgs.devenv;
        };

        mcp-servers.settings.servers = {
          devenv = {
            type = "stdio";
            command = lib.getExe config.programs.devenv.package;
            args = [ "mcp" ];
          };
        };
      };

    _.direnv.hm = _: {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    _.mise.hm = { config, lib, ... }: {
      programs.direnv.mise.enable = false;

      programs.mise = {
        enable = true;
        enableZshIntegration = false;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
        enableMutableConfig = true;
      };

      mcp-servers.settings.servers = {
        mise = {
          command = lib.getExe config.programs.mise.package;
          args = [
            "--cd"
            ""
            "mcp"
          ];
          env = {
            MISE_EXPERIMENTAL = "1";
          };
        };
      };
    };

    _.github.hm = _: {
      programs.gh = {
        enable = true;
        settings = {
          protocol = "ssh";
          prompt = "enabled";
          aliases = { };
        };
      };

      programs.gh-dash.enable = true;

      mcp-servers.programs.github = {
        enable = true;
        passwordCommand = {
          GITHUB_PERSONAL_ACCESS_TOKEN = [
            "gh"
            "auth"
            "token"
          ];
        };
      };
    };

    _.git.hm = { user, ... }: {
      home.shellAliases = {
        lg = "lazygit";
      };

      programs.git = {
        enable = true;
        signing.format = null;
        settings = {
          user = {
            name = user.fullname;
            inherit (user) email;
          };

          color.ui = true;
          init.defaultBranch = "main";
          pull.ff = "only";
          push = {
            default = "current";
            autoSetupRemote = true;
          };
          lfs.enable = true;
        };

        ignores = [
          "_research/"
          ".scratch/"
          ".arxiv/"
          ".devenv/"
          ".direnv/"
        ];
      };

      programs.lazygit = {
        enable = true;
        settings = {
          gui = {
            authorColors = {
              "${user.fullname}" = "#c6a0f6";
              "dependabot[bot]" = "#eed49f";
            };
            branchColors = {
              main = "#ed8796";
              master = "#ed8796";
              dev = "#8bd5ca";
            };
            nerdFontsVersion = "3";
          };
          git.overrideGpg = true;
        };
      };
    };

    _.jujutsu.hm = { user, pkgs, ... }: {
      home.packages = [ pkgs.lazyjj ];
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
          templates.commit_trailers = ''
            format_signed_off_by_trailer(self)
            ++ if(config("rbn.assisted-by.tool") && config("rbn.assisted-by.model"),
                  "Assisted-by: " ++ config("rbn.assisted-by.tool").as_string()
                  ++ " (" ++ config("rbn.assisted-by.model").as_string() ++ ")\n",
                  "")
          '';
        };
      };
    };
  };
}
