# https://zed.dev/docs/configuring-zed#lsp
# https://zed.dev/docs/configuring-zed#languages
# https://zed.dev/docs/languages/toml
# https://zed.dev/extensions/tombi
{ pkgs, ... }:
{
  extensions = [ "marksman" ];
  packages = [ pkgs.marksman ];
  settings = {
    languages.Markdown = {
      tab_size = 2;
      formatter = "language_server";
      language_servers = [ "marksman" ];
    };

    lsp.marksman = { };
  };
}
