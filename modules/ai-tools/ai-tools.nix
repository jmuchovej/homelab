{ inputs, lib, ... }:
let
  ai-tools-lib = import ./_lib.nix {
    inherit lib;
    inherit (inputs) import-tree;
    hooks-dir = ./hooks;
  };

  # Local skills: each `skills/<name>/SKILL.md` is one skill.
  local-skills = ai-tools-lib.load-skills ./skills;

  # Upstream Anthropic skills (subset; rev pinned via the flake input).
  anthropic-skills = ai-tools-lib.pluck-skills inputs.anthropic-skills [
    "docx"
    "frontend-design"
    "mcp-builder"
    "pdf"
    "pptx"
    "skill-creator"
    "webapp-testing"
    "xlsx"
  ];
  # Upstream `marimo` skills (subset; rev pinned via the flake input).
  marimo-skills = ai-tools-lib.pluck-skills inputs.marimo-skills [
    "auto-paper-demo"
    "implement-paper-auto"
    "implement-paper"
    "jupyter-to-marimo"
    "marimo-batch"
    "marimo-notebook"
    "streamlit-to-marimo"
  ];
  upstream-skills = anthropic-skills // marimo-skills;

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
    marimo-skills = {
      flake = false;
      url = "github:marimo-team/skills/6454470960d3cd57151aaeffb1176dd55f598b18";
    };
    mcp-servers.url = "github:natsukium/mcp-servers-nix";
  };

  flake.overlays.llm-agents = inputs.llm-agents.overlays.shared-nixpkgs;

  den.default = {
    hm = {
      imports = [ inputs.mcp-servers.homeManagerModules.default ];
    };
  };

  rbn.programs._.ai-tools = {
    hm = { pkgs, ... }: {
      home.packages = with pkgs.llm-agents; [
        happy-coder
        entire
        agent-browser
        rtk
        openskills
      ];
    };
  };

  rbn.programs._.ai-tools._.mcp = {
    hm = _: {
      programs.mcp.enable = true;

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
      programs.codex.skills = skills;
      programs.opencode.skills = skills;

      home.packages = [ pkgs.llm-agents.openspec ];
    };
  };
}
