{ __findFile, ... }:
{
  rbn.programs._.development._.toolchains._.nuxt = {
    includes = [ <rbn/programs/development/languages/typescript> ];

    hm =
      { lib, pkgs, ... }:
      let
        vue-lsp = lib.rbn.mk-lsp {
          pkg = pkgs.vue-language-server;
          args = [ "--stdio" ];
          extensions.".vue" = "vue";
          init.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        };
      in
      {
        programs.vscode = {
          profiles.default.extensions = with pkgs.open-vsx; [
            vue.volar
          ];
          profiles.default.userSettings = { };
        };

        # https://github.com/zed-extensions/vue
        programs.zed-editor = {
          extensions = [ "vue" ];
          extraPackages = [ vue-lsp.pkg ];
          userSettings = {
            languages."Vue.js" = {
              tab_size = 2;
              formatter = "auto";
              prettier.allowed = false;
            };
            lsp.vue-language-server = vue-lsp.zed;
          };
        };

        programs.claude-code.lspServers = {
          vue = vue-lsp.claude;
        };

        mcp-servers.settings.servers = {
          nuxt = {
            type = "http";
            url = "https://nuxt.com/mcp";
          };
          nuxt-ui = {
            type = "http";
            url = "https://ui.nuxt.com/mcp";
          };
        };
      };
  };
}
