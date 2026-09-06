## Gemini, via the Antigravity CLI: Google's terminal coding agent and the
## successor of Gemini CLI (home-manager renamed `programs.gemini-cli` to
## `programs.antigravity-cli` in May 2026; the option surface is unchanged).
## The aspect is named for the models, not the toolchain. Only the CLI is
## managed here; the Antigravity IDE and desktop app are deliberately not.
{ __findFile, ... }:
{
  rbn.programs._.ai-tools._.gemini = {
    includes = [ <rbn/programs/ai-tools/gemini/cli> ];

    _.cli = {
      includes = [ <rbn/programs/ai-tools/skills> ];

      hm =
        { config, ... }:
        {
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
              GEMINI = ./_ai-tools/BASE.md;
            };

            commands = {
              changelog = {
                prompt = ''
                  Your task is to parse the version, change type, and message from the input
                  and update the CHANGELOG.md file accordingly following
                  conventional commit standards.
                '';
                description = "Update CHANGELOG.md with new entry following conventional commit standards";
              };

              review = {
                prompt = ''
                  Analyze the staged git changes and provide a thorough
                  code review with suggestions for improvement, focusing on
                  code quality, security, and maintainability.
                '';
                description = "Analyze staged git changes and provide thorough code review";
              };

              "git/commit-msg" = {
                prompt = ''
                  Generate a conventional commit message based on the
                  staged changes, following the project's commit standards.
                  Analyze the changes and create an appropriate commit message.
                '';
                description = "Generate conventional commit message based on staged changes";
              };
            };
          };

          # Skills come from the shared `~/.agents/skills` root (skills.nix).
          # Linked directly rather than through `programs.antigravity-cli.skills`,
          # which copies its source into the store and so cannot point at $HOME.
          # Nothing else may be declared under this directory: recent
          # home-manager renders `programs.antigravity-cli.commands` as skills
          # inside it, which is why no commands are defined here.
          home.file.".gemini/antigravity-cli/skills".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
        };
    };

    _.desktop = {
      macos.homebrew.casks = [ "google-gemini" ];
    };
  };
}
