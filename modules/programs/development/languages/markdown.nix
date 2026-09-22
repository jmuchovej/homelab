{
  rbn.programs._.development._.languages._.markdown.hm =
    { lib, pkgs, ... }:
    let
      markdown-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.marksman;
        args = [ "server" ];
        extensions.".md" = "markdown";
      };
    in
    {
      home.packages = [ markdown-lsp.pkg ];

      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          unifiedjs.vscode-mdx
          davidanson.vscode-markdownlint
        ];
        profiles.default.userSettings = { };
      };

      programs.zed-editor = {
        extensions = [ "marksman" ];
        extraPackages = [ markdown-lsp.pkg ];
        userSettings = {
          languages.Markdown = {
            tab_size = 2;
            formatter = "none";
            language_servers = [ "marksman" ];
          };
          lsp.marksman = markdown-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        markdown = markdown-lsp.claude;
      };
    };
}
