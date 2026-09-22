{
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

  rbn.programs._.terminal._.jujutsu.hm =
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
      home.packages = with pkgs; [
        cargo-binstall
        lazyjj
        jj-clone
      ];

      home.shellAliases = {
        jj = "jj --color always";
      };

      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            name = user.fullname;
          };
          git = {
            private-commits = "description('wip:*') | description('private:*')";
          };
          aliases.clone = [
            "util"
            "exec"
            "--"
            (getExe jj-clone)
          ];
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
