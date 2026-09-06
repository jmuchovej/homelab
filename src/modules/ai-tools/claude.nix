{
  __findFile,
  den,
  inputs,
  rbn-policies,
  ...
}:
{
  rbn.programs._.ai-tools._.claude = {
    includes = [
      <rbn/programs/ai-tools/claude/cli>
      (rbn-policies.when-desktop "claude" <rbn/programs/ai-tools/claude/desktop>)
    ];

    _.cli = {
      includes = [
        (den.batteries.unfree [ "claude-code" ])
        <rbn/programs/ai-tools/skills>
        <rbn/programs/ai-tools/skills/claude>
      ];

      hm-linux =
        { pkgs, ... }:
        {
          home.packages = [
            pkgs.bubblewrap
            pkgs.socat
          ];
        };

      hm =
        { lib, pkgs, ... }:
        let
          inherit (inputs) import-tree;
          inherit (import ./_lib.nix { inherit lib import-tree; }) load-tools;

          # Hook scripts live in the shared `hooks/` tree; the wiring into
          # Claude's settings stays Claude-specific under `_claude/`.
          hooks = import ./_claude/hooks.nix {
            inherit pkgs;
            hooks-dir = ./hooks;
          };
          scripts = import ./_claude/scripts.nix {
            inherit pkgs;
            hooks-dir = ./hooks;
          };
        in
        {
          xdg.dataFile."icons/claude.ico".source = ./_claude/assets/claude.ico;

          programs.claude-code = {
            enable = true;
            enableMcpIntegration = true;

            commands = load-tools ./commands;
            agents = load-tools ./agents;

            settings = {
              inherit hooks;

              theme = "auto";
              editorMode = "vim";

              verbose = true;
              includeCoAuthoredBy = false;

              env = {
                USE_BUILTIN_RIPGREP = "0";
                # Plain output from jj, eza and friends; escape codes break
                # parsing. Applies to the session and its subprocesses.
                NO_COLOR = "1";
              };

              statusLine = {
                type = "command";
                command = lib.getExe scripts.status-line;
              };

              sandbox = {
                enabled = false;
                credentials =
                  let
                    mk-credential = key: mode: value: {
                      "${key}" = value;
                      inherit mode;
                    };
                    mk-deny = key: value: mk-credential key "deny" value;
                    mk-mask = key: value: mk-credential key "mask" value;
                    mk-file-deny = path: mk-deny "path" path;
                    mk-env-mask = name: mk-mask "name" name;
                  in
                  {
                    files = [
                      (mk-file-deny "~/.ssh")
                    ];
                    envVars = [
                      (mk-env-mask "SOPS_AGE_KEY")
                      (mk-env-mask "GITHUB_TOKEN")
                    ];
                  };
                network = {
                  allowedDomains = [
                    "raw.githubusercontent.com"
                    "github.com"
                    "openbao.org"
                    "mynixos.com"
                    "registry.terraform.io"
                    "devenv.sh"
                    "flake.parts"
                    "docs.goauthentik.io"
                    "integrations.goauthentik.io"
                    "tailscale.com"
                    "nixos.org"
                    "noogle.dev"
                    "nix.dev"
                    "api.github.com"
                    "kdl.dev"
                    "den.denful.dev"
                    "import-tree.denful.dev"
                    "search.nixos.org"
                    "waypoints.so"
                  ];
                };
              };
            };

            context = ./_system-prompt.md;
          };
        };

      conservative.hm = _: {
        programs.claude-code.settings.permissions = {
          inherit ((import ./_claude/permissions.nix).conservative) allow ask deny;
          defaultMode = "conservative";
        };
      };

      standard.hm = _: {
        programs.claude-code.settings.permissions = {
          inherit ((import ./_claude/permissions.nix).standard) allow ask deny;
          defaultMode = "standard";
        };
      };

      autonomous.hm = _: {
        programs.claude-code.settings.permissions = {
          inherit ((import ./_claude/permissions.nix).autanomous) allow ask deny;
          defaultMode = "autonomous";
        };
      };
    };

    _.desktop = {
      dock.app = "Claude.app";
      macos.homebrew.casks = [ "claude" ];
    };
  };
}
