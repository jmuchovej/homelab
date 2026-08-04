{
  lib,
  import-tree,
  anthropic-skills-src,
}:
let
  inherit (import ./lib.nix { inherit lib import-tree; }) load-tools;

  commands = load-tools ./commands;
  agents = load-tools ./agents;

  # Local skills — each subdir of ./skills/ is one skill.
  local-skills = lib.listToAttrs (
    lib.pipe import-tree [
      (i: i.initFilter (p: lib.hasSuffix "/SKILL.md" (toString p)))
      (i: i.map (p: lib.nameValuePair (baseNameOf (dirOf p)) (dirOf p)))
      (i: i.leafs ./skills)
    ]
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
