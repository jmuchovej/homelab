## OpenCode: OpenAI's terminal coding agent. Only the CLI is managed here — there
## is no opencode desktop app to pair with, unlike Claude and Gemini.
##
## `programs.opencode` looks superficially like `programs.antigravity-cli` but
## shares almost none of its schema: `settings` is opencode's `config.toml`
## (<https://developers.openai.com/opencode/config-reference>), `context` is a bare
## path rather than an attrset of named files, and there is no `defaultModel`.
{ __findFile, inputs, ... }:
{
  rbn.programs._.ai-tools._.opencode = {
    includes = [ <rbn/programs/ai-tools/opencode/cli> ];

    _.cli = {
      includes = [
        <rbn/programs/ai-tools/skills>
      ];

      hm = { lib, pkgs, ... }: {
        programs.opencode = {
          enable = true;
          context = ./_system-prompt.md;
          tui = {
            theme = "system";
          };
          web = { };
        };
      };
    };
  };
}
