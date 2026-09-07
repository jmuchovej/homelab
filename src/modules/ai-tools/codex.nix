## Codex: OpenAI's terminal coding agent. Only the CLI is managed here — there
## is no Codex desktop app to pair with, unlike Claude and Gemini.
##
## `programs.codex` looks superficially like `programs.antigravity-cli` but
## shares almost none of its schema: `settings` is Codex's `config.toml`
## (<https://developers.openai.com/codex/config-reference>), `context` is a bare
## path rather than an attrset of named files, and there is no `defaultModel`.
{ __findFile, inputs, ... }: {
  rbn.programs._.ai-tools._.codex = {
    includes = [ <rbn/programs/ai-tools/codex/cli> ];

    _.cli = {
      includes = [
        <rbn/programs/ai-tools/skills>
      ];

      hm = { lib, pkgs, ... }: {
        programs.codex = {
          enable = true;
          enableMcpIntegration = true;
          context = ./_system-prompt.md;
        };
      };
    };
  };
}
