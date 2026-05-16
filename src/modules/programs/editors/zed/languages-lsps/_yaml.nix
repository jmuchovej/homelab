# https://zed.dev/docs/configuring-zed#lsp
# https://zed.dev/docs/configuring-zed#languages
# https://zed.dev/docs/languages/yaml
{ pkgs, ... }:
{
  extensions = [ ];
  packages = [
    pkgs.yamlfmt
    pkgs.yaml-language-server
  ];
  settings = {
    languages.YAML = {
      tab_size = 2;
      formatter = "language_server";
    };

    lsp.yaml-language-server = {
      settings = {
        yaml = {
          keyOrdering = false;
        };
        format = {
          singleQuote = false;
        };
      };
    };
  };

}
