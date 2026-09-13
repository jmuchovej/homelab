{ __findFile, ... }:
{
  rbn.programs._.development._.toolchains._.astro = {
    includes = [ <rbn/programs/development/languages/typescript> ];

    hm =
      { lib, pkgs, ... }:
      let
        inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

        # Volar-based servers locate TypeScript at runtime and cannot fall back
        # to a bundled copy under nix; without an explicit tsdk they start and
        # then answer every request with nothing.
        astro-lsp = mk-lsp {
          pkg = pkgs.astro-language-server;
          args = [ "--stdio" ];
          extensions.".astro" = "astro";
          init.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        };
      in
      {
        # https://github.com/zed-extensions/astro
        programs.zed-editor = {
          extensions = [ "astro" ];
          extraPackages = [ astro-lsp.pkg ];
          userSettings = {
            languages.Astro = {
              tab_size = 2;
              formatter = "auto";
              prettier.allowed = false;
            };
            lsp.astro-language-server = astro-lsp.zed;
          };
        };

        programs.claude-code.lspServers = {
          astro = astro-lsp.claude;
        };

        mcp-servers.settings.servers = {
          astro = {
            type = "http";
            url = "https://mcp.docs.astro.build/mcp";
          };
        };
      };
  };
}
