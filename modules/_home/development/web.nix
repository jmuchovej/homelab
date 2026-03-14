{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.web";
  config =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mk-zed-settings;

      vsc-extensions = with pkgs.open-vsx; [
        # astro-build.astro-vscode
        oven.bun-vscode
        unifiedjs.vscode-mdx
        davidanson.vscode-markdownlint
        bradlc.vscode-tailwindcss
        stylelint.vscode-stylelint
        esbenp.prettier-vscode
        vue.volar
        # antfu.slidev
        dbaeumer.vscode-eslint
      ];
      vsc-user-settings = {
        # "[astro]"
      };

      zed = mk-zed-settings {
        extensions = [
          # https://github.com/zed-extensions/astro
          "astro"
          # https://github.com/biomejs/biome-zed/
          "biome"
          # https://github.com/zed-extensions/vue
          "vue"
        ];
        packages = [ pkgs.biome ];
        settings = {
          languages.JavaScript = {
            tab_size = 2;
            formatter = "auto";
            prettier.allowed = false;
            code_actions_on_format = {
              "source.fixAll.biome" = true;
              "source.organizeImports.biome" = true;
            };
          };
          languages.TypeScript = {
            tab_size = 2;
            formatter = "auto";
            prettier.allowed = false;
            code_actions_on_format = {
              "source.fixAll.biome" = true;
              "source.organizeImports.biome" = true;
            };
          };
          languages.HTML = {
            tab_size = 2;
            formatter = "auto";
          };
          languages.Astro = {
            tab_size = 2;
            formatter = "auto";
          };
          languages."Vue.js" = {
            tab_size = 2;
            formatter = "auto";
          };
          languages.TSX = {
            tab_size = 2;
            formatter = "auto";
            code_actions_on_format = {
              "source.fixAll.biome" = true;
              "source.organizeImports.biome" = true;
            };
          };
          languages.CSS = {
            tab_size = 2;
            formatter = "auto";
          };
          lsp.biome = {
            settings = { };
          };
        };
      };
    in
    {
      programs.bun = {
        enable = true;
        enableGitIntegration = true;
      };

      home.packages = with pkgs; [
        biome
        deno
      ];

      programs.vscode = mkIf config.rebellion.editor.vscode.enable {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
