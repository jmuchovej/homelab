{
  rbn.suite._.development.hm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        pre-commit
        prek
        treefmt
        tokei
        onefetch
        act

        nix-tree
        nix-du
        graphviz
        nix-init
        nix-melt
        nix-update
        nixpkgs-fmt
        nixpkgs-hammering
        nixpkgs-review
        nurl

        delta
        difftastic

        lazyjj

        (writeShellScriptBin "closure-size" ''
          nix path-info --recursive --closure-size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')

        (writeShellScriptBin "store-size" ''
          nix path-info --recursive --size --human-readable \
            "''${1:-/run/current-system}" | sort --human-numeric-sort --key=2
        '')
      ];

      home.shellAliases =
        let
          nr-bin = lib.getExe pkgs.nixpkgs-review;
        in
        {
          prefetch-sri = "nix store prefetch-file $1";
          nrh = "${nr-bin} rev HEAD";
          nra = ''${nr-bin} pr $1 --systems "all"'';
          nrap = ''${nr-bin} pr $1 --systems "all" --post-result --num-parallel-evals 4'';
          nrd = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2'';
          nrdp = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin" --num-parallel-evals 2 --post-result'';
          nrl = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2'';
          nrlp = ''${nr-bin} pr $1 --systems "x86_64-linux aarch64-linux" --num-parallel-evals 2 --post-result'';
          nrmp = ''${nr-bin} pr $1 --systems "x86_64-darwin aarch64-darwin aarch64-linux" --num-parallel-evals 3 --post-result'';
          nup = "nix-shell maintainers/scripts/update.nix --argstr package $1";
          num = "nix-shell maintainers/scripts/update.nix --argstr maintainer $1";
          lg = "lazygit";
        };

      programs = {
        devenv.enable = true;

        direnv = {
          enable = true;
          nix-direnv.enable = true;
          mise.enable = false;
        };

        mise = {
          enable = true;
          enableZshIntegration = false;
          enableBashIntegration = false;
          enableFishIntegration = false;
          enableNushellIntegration = false;
          enableMutableConfig = true;
        };

        gh = {
          enable = true;
          settings = {
            protocol = "ssh";
            prompt = "enabled";
            aliases = { };
          };
        };

        gh-dash.enable = true;
        git-credential-oauth.enable = true;

        git = {
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

        lazygit = {
          enable = true;

          settings = {
            gui = {
              authorColors = {
                "${config.programs.git.settings.user.name or "John Muchovej"}" = "#c6a0f6";
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

        jujutsu = {
          enable = true;

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

      xdg.configFile."git/ignore" = {
        enable = true;
        text = ''
          _research/
          .scratch/
          .arxiv/
          .devenv/
          .direnv/
        '';
      };
    };
}
