{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.lazygit";
  config =
    { cfg, config, ... }:
    {
      programs.lazygit = {
        enable = true;

        settings = {
          gui = {
            authorColors = {
              "${config.rebellion.user.fullName}" = "#c6a0f6";
              "dependabot[bot]" = "#eed49f";
            };
            branchColors = {
              main = "#ed8796";
              master = "#ed8796";
              dev = "#8bd5ca";
            };
            nerdFontsVersion = "3";
          };
          git = {
            overrideGpg = true;
          };
        };
      };

      home.shellAliases = {
        lg = "lazygit";
      };
    };
}
