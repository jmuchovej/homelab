{ lib, pkgs, ... }:

let
  inherit (lib.rebellion.ai-tools) load-tools;

  commands = load-tools ./ai-tools/commands;
  agents = load-tools ./ai-tools/agents;

  # Upstream Anthropic skills, fetched from GitHub and pinned to a specific commit.
  # To update: change `rev` and `hash` (run `nix-prefetch-url --unpack` to get new hash).
  anthropic-skills-src = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "1ed29a03dc852d30fa6ef2ca53a67dc2c2c2c563";
    hash = "sha256-9FGubcwHcGBJcKl02aJ+YsTMiwDOdgU/FHALjARG51c=";
  };

  # Which upstream skills to include (maps local name -> upstream directory name).
  anthropic-skill-names = [
    "docx"
    "frontend-design"
    "mcp-builder"
    "pdf"
    "pptx"
    "skill-creator"
    "webapp-testing"
    "xlsx"
  ];

  # Combine local skills with selected upstream Anthropic skills into a single directory.
  skills = pkgs.symlinkJoin {
    name = "ai-tools-skills";
    paths = [
      ./ai-tools/skills
    ]
    ++ map (name: "${anthropic-skills-src}/skills/${name}") anthropic-skill-names;
  };
in
{
  inherit skills;

  claude-code = {
    inherit commands agents;
  };
}
