{
  rbn.programs._.development._.languages._.typescript.hm =
    { lib, pkgs, ... }:
    let
      inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

      ts-lsp = mk-lsp {
        pkg = pkgs.vtsls;
        args = [ "--stdio" ];
        extensions = {
          ".ts" = "typescript";
          ".mts" = "typescript";
          ".cts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".mjs" = "javascript";
          ".cjs" = "javascript";
          ".jsx" = "javascriptreact";
        };
      };
    in
    {
      programs.bun = {
        enable = true;
        enableGitIntegration = true;
      };

      home.packages = [ pkgs.deno ];

      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          oven.bun-vscode
          bradlc.vscode-tailwindcss
          stylelint.vscode-stylelint
          esbenp.prettier-vscode
          dbaeumer.vscode-eslint
        ];
        profiles.default.userSettings = { };
      };

      programs.zed-editor = {
        extensions = [
        ];
        extraPackages = [ ts-lsp.pkg ];
        userSettings =
          let
            languages-default = {
              tab_size = 2;
              formatter = "auto";
              prettier.allowed = false;
            };
            biome-actions = {
              code_actions_on_format = { };
            };
          in
          {
            languages.JavaScript = languages-default // biome-actions;
            languages.TypeScript = languages-default // biome-actions;
            languages.TSX = languages-default // biome-actions;
            languages.HTML = languages-default;
            languages.CSS = languages-default;
            lsp.vtsls =
              let
                shared-settings = {
                  updateImportsOnFileMove.enabled = "always";
                  suggest.completeFunctionCalls = true;
                  tsserver = {
                    watch.usePolling = false;
                    maxTsServerMemory = 8092;
                  };
                };
              in
              ts-lsp.zed
              // {
                settings.typescript = shared-settings;
                settings.javascript = shared-settings;
                enable_lsp_tasks = true;
              };
          };
      };

      programs.claude-code.lspServers = {
        typescript = ts-lsp.claude;
      };

      mcp-servers.settings.servers = {
        npmx = {
          type = "http";
          url = "https://docs.npmx.dev/mcp";
        };
      };
    };
}
