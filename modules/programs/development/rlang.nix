_: {
  rbn.programs._.development._.rlang.homeManager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;

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

      vsc-extensions = with pkgs.open-vsx; [
        reditorsupport.r
      ];
      vsc-user-settings = { };

      # https://zed.dev/docs/languages/r
      zed = {
        extensions = [
          "r"
          "air"
        ];
        extraPackages = [
          pkgs.air-formatter
          (pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              air
              languageserver
              lintr
            ];
          })
        ];
        userSettings = {
          lsp.air = {
          };
          languages.R = {
            tab_size = 2;
            language_servers = [ "air" ];
          };
        };
      };
    in
    {
      # FIXME: R appears to be broken due to some issues with `r-curl`???
      home.packages = [ R ];

      programs.vscode = mkIf (config.programs.vscode.enable or false) {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
