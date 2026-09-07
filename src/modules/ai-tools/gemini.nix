## Gemini, via the Antigravity CLI: Google's terminal coding agent and the
## successor of Gemini CLI (home-manager renamed `programs.gemini-cli` to
## `programs.antigravity-cli` in May 2026; the option surface is unchanged).
## The aspect is named for the models, not the toolchain. Only the CLI is
## managed here; the Antigravity IDE and desktop app are deliberately not.
{
  __findFile,
  den,
  inputs,
  ...
}:
{
  rbn.programs._.ai-tools._.gemini = {
    includes = [ <rbn/programs/ai-tools/gemini/cli> ];

    _.cli = {
      includes = [
        <rbn/programs/ai-tools/skills>
        (den.batteries.unfree [ "antigravity-cli" ])
      ];

      hm = { lib, pkgs, ... }: {
        # Gemini CLI loads ~/.gemini/.env into its process environment, so the
        # shell tool's subprocesses inherit it. Same intent as Claude's env.
        home.file.".gemini/.env".text = ''
          NO_COLOR=1
        '';

        programs.antigravity-cli = {
          enable = true;

          settings = {
            ui.theme = "Default";

            general = {
              vimMode = true;
              preferredEditor = "nvim";
              previewFeatures = true;
            };
            tools.autoAccept = false;
            security.auth.selectedType = "gemini-api-key";
          };

          defaultModel = "auto";
          # Global system prompt shared by every agent; Claude uses the same file.
          context = {
            GEMINI = ./_system-prompt.md;
          };
        };

        # Skills are linked by `ai-tools/skills/gemini` (see ai-tools.nix).
        # Nothing else may be declared under `.gemini/antigravity-cli/skills`:
        # recent home-manager renders `programs.antigravity-cli.commands` as
        # skills inside it, which is why no commands are defined here.
      };
    };

    _.desktop = {
      macos.homebrew.casks = [ "google-gemini" ];
    };
  };
}
