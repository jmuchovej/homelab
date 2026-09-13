{ __findFile, ... }:
{
  rbn.programs._.development._.toolchains._.nuxt = {
    includes = [ <rbn/programs/development/languages/typescript> ];

    hm =
      { lib, pkgs, ... }:
      let
        inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

        # Volar-based servers locate TypeScript at runtime and cannot fall back
        # to a bundled copy under nix; without an explicit tsdk they start and
        # then answer every request with nothing.
        vue-lsp = mk-lsp {
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
