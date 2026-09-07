## Lua is used for editor/terminal config (wezterm), not application code, so
## the server is scoped hard rather than left to discover a project root.
##
## `ignoreDir` is load-bearing: lua-ls reads ONLY `<root>/.gitignore` and
## `<root>/.git/info/exclude` (script/workspace/workspace.lua), never
## `core.excludesFile` and never a nested `.gitignore`. Directories hidden by
## the global git ignore — `.scratch/` alone is ~190k files — are therefore
## fully visible to it, and scanning them stalls startup for ~12s.
{
  rbn.programs._.development._.languages._.lua.hm =
    { lib, pkgs, ... }:
    let
      lua-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.lua-language-server;
        extensions.".lua" = "lua";
        settings.Lua = {
          runtime.version = "Lua 5.4";
          telemetry.enable = false;
          workspace = {
            useGitIgnore = true;
            # Replaces the default (`.vscode`) rather than extending it.
            ignoreDir = [
              ".vscode"
              ".scratch"
              ".direnv"
              ".jj"
              "docs"
              "node_modules"
              "result"
            ];
          };
        };
      };
    in
    {
      home.packages = [ lua-lsp.pkg ];

      programs.zed-editor = {
        # https://zed.dev/docs/languages/lua
        extensions = [ "lua" ];
        extraPackages = [ lua-lsp.pkg ];
        userSettings = {
          languages.Lua = {
            tab_size = 2;
            formatter = "language_server";
            language_servers = [ "lua-language-server" ];
          };
          lsp.lua-language-server = lua-lsp.zed;
        };
      };

      programs.claude-code.lspServers.lua = lua-lsp.claude;
    };
}
