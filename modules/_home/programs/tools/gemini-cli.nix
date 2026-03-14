{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.gemini-cli";
  config =
    {
      lib,
      pkgs,
      osConfig,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.fs) get-file;
    in
    {
      programs.gemini-cli = {
        enable = true;

        settings = {
          ui.theme = "Default";

          general = {
            vimMode = true;
            preferredEditor = "nvim";
            previewFeatures = true;
          };
          tools.autoAccept = false;
          security.auth.selectedType = mkIf (osConfig.rebellion.security.sops.enable or false
          ) "gemini-api-key";
        };

        defaultModel = "auto";
        context = {
          GEMINI = get-file "modules/_common/ai-tools/BASE.md";
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
    };
}
