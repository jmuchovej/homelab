{
  __findFile,
  den,
  inputs,
  rbn-policies,
  ...
}:
{
  flake-file.inputs.anthropic-skills = {
    flake = false;
    url = "github:anthropics/skills/1ed29a03dc852d30fa6ef2ca53a67dc2c2c2c563";
  };

  rbn.programs._.ai-tools._.claude = {
    includes = [
      <rbn/programs/ai-tools/claude/code>
      (rbn-policies.when-desktop "claude" <rbn/programs/ai-tools/claude/desktop>)
    ];

    _.code = {
      includes = [ (den.batteries.unfree [ "claude-code" ]) ];

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

          ai-tools = import ./_ai-tools {
            inherit lib import-tree;
            anthropic-skills-src = inputs.anthropic-skills;
          };
          inherit (ai-tools) claude-code;

          hooks = import ./_claude/hooks.nix { inherit pkgs; };
          scripts = import ./_claude/scripts.nix { inherit pkgs; };
        in
        {
          xdg.dataFile."icons/claude.ico".source = ./_claude/assets/claude.ico;

          programs.claude-code = {
            enable = true;
            enableMcpIntegration = true;

            inherit (claude-code) agents commands;

            settings = {
              inherit (ai-tools) skills;
              inherit hooks;

              theme = "auto";
              editorMode = "vim";

              verbose = true;
              includeCoAuthoredBy = false;

              env = {
                USE_BUILTIN_RIPGREP = "0";
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

            context = ./_ai-tools/BASE.md;
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
