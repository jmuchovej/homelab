## Global skills, published once to `~/.agents/skills`: the shared root Codex
## and Antigravity read directly. Harness aspects that only look in their own
## directory link into it (see `claude.nix` and `antigravity.nix`).
{ inputs, ... }:
{
  rbn.programs._.ai-tools._.skills.hm =
    { lib, ... }:
    let
      inherit
        (import ./_ai-tools {
          inherit lib;
          inherit (inputs) import-tree;
          anthropic-skills-src = inputs.anthropic-skills;
        })
        skills
        ;
    in
    {
      home.file = lib.mapAttrs' (
        name: path: lib.nameValuePair ".agents/skills/${name}" { source = path; }
      ) skills;
    };
}
