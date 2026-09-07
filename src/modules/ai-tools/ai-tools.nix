{ inputs, lib, ... }:
let
  inherit
    (import ./_lib.nix {
      inherit lib;
      inherit (inputs) import-tree;
    })
    load-skills
    ;

  # Local skills: each `skills/<name>/SKILL.md` is one skill.
  local-skills = load-skills ./skills;

  # Upstream Anthropic skills (subset; rev pinned via the flake input).
  upstream-skills = lib.genAttrs [
    "docx"
    "frontend-design"
    "mcp-builder"
    "pdf"
    "pptx"
    "skill-creator"
    "webapp-testing"
    "xlsx"
  ] (name: inputs.anthropic-skills + "/skills/${name}");

  skills = local-skills // upstream-skills;

  skills-tree = ".agents/skills";
in
{
  flake-file.inputs = {
    llm-agents.url = "github:numtide/llm-agents.nix";
    anthropic-skills = {
      flake = false;
      url = "github:anthropics/skills/1ed29a03dc852d30fa6ef2ca53a67dc2c2c2c563";
    };
    mcp-servers.url = "github:natsukium/mcp-servers-nix";
  };

  den.default = {
    hm = {
      imports = [ inputs.mcp-servers.homeManagerModules.default ];
    };
    os = {
      nixpkgs.overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];
    };
  };

  rbn.programs._.ai-tools._.mcp = {
    hm = { lib, pkgs, ... }: {
      programs.mcp.enable = true;

      mcp-servers.settings.servers = {
        devenv = {
          type = "stdio";
          command = lib.getExe pkgs.devenv;
          args = [ "mcp" ];
        };
      };

      programs.claude-code.enableMcpIntegration = true;
      programs.antigravity-cli.enableMcpIntegration = true;
      programs.opencode.enableMcpIntegration = true;
      programs.codex.enableMcpIntegration = true;
    };
  };

  rbn.programs._.ai-tools._.skills = {
    hm = { pkgs, lib, ... }: {
      home.file = lib.mapAttrs' (
        name: path: lib.nameValuePair "${skills-tree}/${name}" { source = path; }
      ) skills;

      programs.claude-code.skills = skills;
      programs.antigravity-cli.skills = skills;

      home.packages = [ pkgs.llm-agents.openspec ];
    };
  };
}
