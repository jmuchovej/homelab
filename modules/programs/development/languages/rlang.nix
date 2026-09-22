{
  rbn.programs._.development._.languages._.rlang.hm =
    { lib, pkgs, ... }:
    let
      air-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.air-formatter;
        args = [ "language-server" ];
        extensions = {
          ".R" = "r";
          ".r" = "r";
        };
      };

      default-packages = with pkgs.rPackages; [
        # Tidyverse and friends
        tidyverse
        tidymodels
        pastecs
        # Document Writing
        quarto
        # Language Server
        languageserver
      ];

      R = pkgs.rWrapper.override { packages = default-packages; };
      # RStudio = pkgs.rstudioWrapper.override { packages = default-packages; };
    in
    {
      # FIXME: R appears to be broken due to some issues with `r-curl`???
      home.packages = [ R ];

      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          reditorsupport.r
        ];
        profiles.default.userSettings = { };
      };

      # https://zed.dev/docs/languages/r
      programs.zed-editor = {
        extensions = [
          "r"
          "air"
        ];
        extraPackages = [
          air-lsp.pkg
          (pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              air
              languageserver
              lintr
            ];
          })
        ];
        userSettings = {
          lsp.air = air-lsp.zed;
          languages.R = {
            tab_size = 2;
            formatter = "language_server";
            language_servers = [ "air" ];
          };
        };
      };

      programs.claude-code.lspServers = {
        r = air-lsp.claude;
      };
    };
}
