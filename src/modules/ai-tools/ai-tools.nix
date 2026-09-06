{ inputs, lib, ... }:
let
  # Local skills: each `skills/<name>/SKILL.md` is one skill.
  local-skills = lib.listToAttrs (
    lib.pipe inputs.import-tree [
      (i: i.initFilter (p: lib.hasSuffix "/SKILL.md" (toString p)))
      (i: i.map (p: lib.nameValuePair (baseNameOf (dirOf p)) (dirOf p)))
      (i: i.leaves ./skills)
    ]
  );

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

  # den does not honour `imports` on an aspect; the module has to be imported
  # at class level for the `mcp-servers.*` options to exist.
  den.default.homeManager.imports = [ inputs.mcp-servers.homeManagerModules.default ];

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
    hm = { lib, ... }: {
      home.file = lib.mapAttrs' (
        name: path: lib.nameValuePair "${skills-tree}/${name}" { source = path; }
      ) skills;
    };

    # `~/.claude/skills/` has to stay a real directory because home-manager
    # installs plugin skills into it, so each skill is linked individually.
    _.claude.hm =
      { config, lib, ... }:
      let
        home-skills = "${config.home.homeDirectory}/${skills-tree}";
        mk-symlink = config.lib.file.mkOutOfStoreSymlink;
      in
      {
        home.file = lib.mapAttrs' (
          name: _:
          lib.nameValuePair ".claude/skills/${name}" {
            source = mk-symlink "${home-skills}/${name}";
          }
        ) skills;
      };

    # Whole-root link, not `programs.antigravity-cli.skills`: that option copies
    # its source into the store and so cannot point at $HOME.
    _.gemini.hm =
      { config, ... }:
      let
        home-skills = "${config.home.homeDirectory}/${skills-tree}";
        mk-symlink = config.lib.file.mkOutOfStoreSymlink;
      in
      {
        home.file.".gemini/antigravity-cli/skills".source = mk-symlink home-skills;
      };
  };
}
