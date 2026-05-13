{ lib, anthropic-skills-src }:

let
  inherit (lib.rebellion.ai-tools) load-tools;

  commands = load-tools ./commands;
  agents = load-tools ./agents;

  # Local skills — each subdir of ./skills/ is one skill.
  local-skills = lib.mapAttrs' (name: _: lib.nameValuePair name (./skills + "/${name}")) (
    builtins.readDir ./skills
  );

  # Upstream Anthropic skills (subset; rev pinned via flake input).
  upstream-skill-names = [
    "docx"
    "frontend-design"
    "mcp-builder"
    "pdf"
    "pptx"
    "skill-creator"
    "webapp-testing"
    "xlsx"
  ];
  upstream-skills = lib.listToAttrs (
    map (name: lib.nameValuePair name (anthropic-skills-src + "/skills/${name}")) upstream-skill-names
  );

  # name -> path attrset; consumed directly by the claude-code HM module.
  # No symlinkJoin = no derivation = no IFD = no cross-arch build needed.
  skills = local-skills // upstream-skills;
in
{
  inherit skills;

  claude-code = {
    inherit commands agents;
  };
}
