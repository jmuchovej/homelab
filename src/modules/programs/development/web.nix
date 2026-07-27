{
  rbn.programs._.development._.web.homeManager = { pkgs, ... }: {
    programs.bun = {
      enable = true;
      enableGitIntegration = true;
    };

    home.packages = with pkgs; [
      deno
    ];

    programs.vscode = {
      profiles.default.extensions = with pkgs.open-vsx; [
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
      profiles.default.userSettings = {
        # "[astro]"
      };
    };

    programs.zed-editor = {
      extensions = [
        # https://github.com/zed-extensions/astro
        "astro"
        # https://github.com/biomejs/biome-zed/
        # "biome"
        # https://github.com/zed-extensions/vue
        "vue"
      ];
      extraPackages = [ ];
      userSettings = {
        languages.JavaScript = {
          tab_size = 2;
          formatter = "auto";
          prettier.allowed = false;
          code_actions_on_format = {
            # "source.fixAll.biome" = true;
            # "source.organizeImports.biome" = true;
          };
        };
        languages.TypeScript = {
          tab_size = 2;
          formatter = "auto";
          prettier.allowed = false;
          code_actions_on_format = {
            # "source.fixAll.biome" = true;
            # "source.organizeImports.biome" = true;
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
            # "source.fixAll.biome" = true;
            # "source.organizeImports.biome" = true;
          };
        };
        languages.CSS = {
          tab_size = 2;
          formatter = "auto";
        };
      };
    };
  };
}
