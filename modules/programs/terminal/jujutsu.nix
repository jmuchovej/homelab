{ __findFile, ... }: {
  den.schema.user =
    { lib, ... }:
    let
      mk-str =
        description:
        lib.mkOption {
          inherit description;
          type = lib.types.str;
        };

      forges-module = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            host = mk-str "Real clone host (differs from the key for sr.ht).";
            short = mk-str "`short:owner/repo` shorthand expanded by git's `insteadOf`.";
            email = mk-str "Author email for repos under this forge.";
            signing-key = (mk-str "SSH public key to sign with; falls back to the global key.") // {
              default = "";
            };
          };
        }
      );
    in
    {
      options.forges = lib.mkOption {
        type = forges-module;
        default = { };
        description = ''
          Per-forge identity, keyed by the directory under `~/Documents/src`.
          Drives the jj `user.email` scopes, git's `insteadOf` shorthands, and
          the clone helper's directory table.
        '';
      };
    };

  rbn.programs._.terminal._.jujutsu = {
    includes = [ <rbn/programs/terminal/jj-hooks> ];
    hm =
      {
        user,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib) getExe mapAttrsToList;

        dump-forge = key: val: "  ${builtins.toJSON key}: ${builtins.toJSON val}";
        ## Both the shorthand and the real clone host key the same directory,
        ## so the helper and git's `insteadOf` cannot disagree.
        dump-forges = dir: forge: ''
          ${dump-forge forge.short dir},
          ${dump-forge forge.host dir},
        '';

        jj-clone-src = builtins.readFile ./jj-clone-forge.nu;
        jj-clone-script = lib.replaceString "const FORGES = {} # @@forge-dirs@@" ''
          const FORGES = {
            ${lib.trim (lib.concatStrings (mapAttrsToList dump-forges user.forges))}
          }
        '' jj-clone-src;
        ## `writeNuBin` has no checker of its own; `nu-check --debug` turns a
        ## parse error into a failed build, as `ai-tools/_lib.nix` does.
        jj-clone = pkgs.writers.writeNuBin "jj-clone-forge" {
          check = pkgs.writeShellScript "nu-check" ''
            ${getExe pkgs.nushell} --no-config-file --commands "if not (nu-check --debug '$1') { exit 1 }"
          '';
        } jj-clone-script;
      in
      {
        home.packages = [
          jj-clone
          pkgs.watchman
        ];

        home.shellAliases = {
          jj = "jj --color always";
        };

        programs.jjui = {
          enable = true;
          settings = {
          };
        };

        programs.jujutsu = {
          enable = true;
          settings = {
            user = {
              name = user.fullname;
            };
            git = {
              private-commits = "description('wip:*') | description('private:*')";
              track-default-bookmark-on-clone = true;
              write-change-id-header = true;
              colocate = true;
            };
            remotes = {
              origin = {
                auto-track-bookmarks = "*";
              };
              upstream = {
                auto-track-bookmarks = "*";
              };
            };
            snapshot = {
              auto-update-stale = true;
              auto-track = lib.concatMapStringsSep " & " (g: ''~glob:"${g}"'') [
                "*~"
                ".*.swp"
                "node_modules"
                ".devenv"
                ".DS_Store"
                "mise.*.local.toml"
                "mise.local.toml"
              ];
            };
            ui = {
              default-command = "log";
              conflict-marker-style = "git";
            };
            fsmonitor = {
              backend = "watchman";
              watchman.register-snapshot-trigger = true;
            };
            aliases = with lib.rbn; {
              clone = argv "util exec -- ${getExe jj-clone}";
              sq = "squash";

              rebase-trunk = argv "rebase -b @ -d trunk()";
              rebase-all-trunk = argv "rebase -b (visible_heads() ~ immutable_heads()) & working_set() -d trunk()";

              log-all = argv "log -r ::";
              log-branches = argv "log -r branch_log()";
            };
            revsets = {
              log = "ancestors(working_set(), 2)";
              bookmark-advance-to = "closest_pushable(@)";
            };
            revset-aliases = {
              "archive_refs()" = ''bookmarks(glob:"archive/*")'';
              "working_refs()" = "present(@) | present(trunk()) | (bookmarks() ~ archive_refs())";
              "archive()" = "::archive_refs() ~ ::((~::archive_refs()) | working_refs())";

              "live_heads()" = "heads(mutable() ~ archive())";
              "live_fork_point()" = "fork_point(live_heads())";

              "working_heads()" =
                "live_heads() | present(@) | present(trunk()) | first_parent(@) | working_copies()";
              "working_fork_point()" = "fork_point(working_heads())";
              "working_set()" = "connected(working_heads() | working_fork_point())";

              "branch_heads()" = "working_heads() | remote_bookmarks()";
              "branch_fork_point()" = "fork_point(branch_heads())";
              "branch_set()" = "connected(branch_heads() | branch_fork_point())";
              "branch_log()" = "ancestors(branch_set(), 2)";

              "closest_pushable(to)" =
                ''heads(::to & mutable() & ~description(exact:"") & (~empty() | merges()))'';
            };
            template-aliases = {
              "format_timestamp(timestamp)" = "timestamp.ago()";
              "micro_commit_info(c)" = ''
                concat(
                  if(c.immutable(), label("immutable", "◆")),
                  coalesce(
                    if(c.empty() && !c.immutable(), label("empty", "empty")),
                    c.change_id().shortest()
                  ),
                  if(c.conflict(), label("conflict", "×")),
                  coalesce(
                    if(c.contained_in("trunk()"), label("git_head", "⊙")),
                    if(c.contained_in("trunk()::"), label("git_head", "↑")),
                    if(c.contained_in("::trunk()"), "↓"),
                    "→"
                  )
                )
              '';
              commit_and_parents_info = ''
                separate(
                  ", ",
                  micro_commit_info(self),
                  parents.map(|c| micro_commit_info(c)).join("+")
                )
              '';
              assisted_by_tool = ''config("rbn.assisted-by.tool")'';
              assisted_by_model = ''config("rbn.assisted-by.model")'';
              "format_assisted_by_trailer(commit)" = ''
                if(assisted_by_tool && assisted_by_model,
                  "Assisted-by: " ++ assisted_by_tool.as_string() ++ " (" ++ assisted_by_model.as_string() ++ ")\n",
                  "")
              '';
            };
            templates = {
              commit_trailers = ''
                format_signed_off_by_trailer(self)
                ++ format_assisted_by_trailer(self)
              '';
            };
            "--scope" =
              let
                ## Repos live under `~/Documents/src`; the view directories hold
                ## only symlinks. jj resolves symlinks before matching, so the
                ## scope must key on the real storage path.
                mk-forge-scope =
                  dir: forge:
                  {
                    "--when".repositories = [ "~/Documents/src/${dir}" ];
                    user.email = forge.email;
                  }
                  // lib.optionalAttrs (forge.signing-key != "") {
                    signing.key = forge.signing-key;
                  };
              in
              [
                {
                  "--when".commands = [ "status" ];
                  ui.paginate = "never";
                }
              ]
              ++ mapAttrsToList mk-forge-scope user.forges;
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
  };

  rbn.programs._.terminal._.jj-hooks.hm = { lib, pkgs, ... }: {
    home.packages = [ pkgs.rbn.jj-hooks ];
    programs.jujutsu = {
      settings = {
        aliases = {
          push = lib.rbn.argv "util exec -- jj-hp push";
        };

        jj-hooks = {
          advance-bookmarks = true;
        };
      };
    };

    programs.jjui = {
      settings = {
        actions = [
          {
            name = "jj-hp-push-selected";
            lua = ''
              jj_async("util", "exec", "--", "jj-hp", "push", "-r", context.commit_id())
              revisions.refresh()
            '';
          }
          {
            name = "jj-hp-push";
            lua = ''
              jj_async("util", "exec", "--", "jj-hp", "push", "--all")
              revisions.refresh()
            '';
          }
        ];
        bindings = [
          {
            action = "jj-hp-push-selected";
            desc = "jj-hp push selected bookmark";
            scope = "revisions";
            seq = [
              "x"
              "p"
            ];
          }
          {
            action = "jj-hp-push";
            desc = "jj-hp push all bookmarks";
            scope = "revisions";
            seq = [
              "x"
              "P"
            ];
          }
        ];
      };
    };
  };
}
