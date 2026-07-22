# https://zed.dev/docs/configuring-zed#lsp
# https://zed.dev/docs/configuring-zed#languages
# https://zed.dev/docs/languages/toml
# https://zed.dev/extensions/tombi
{ pkgs, ... }:
{
  extensions = [ "tombi" ];
  packages = [ pkgs.tombi ];
  settings = {
    languages.TOML = {
      tab_size = 2;
      formatter = "language_server";
    };

    # https://github.com/tombi-toml/tombi/blob/main/docs/src/routes/docs/editors/zed-extension.mdx
    # https://tombi-toml.github.io/tombi/docs/editors/zed-extension
    lsp.tombi = {
      binary = {
        arguments = [
          "lsp"
          "-v"
        ];
        env = {
          NO_COLOR = "true";
        };
      };
    };
  };
}
