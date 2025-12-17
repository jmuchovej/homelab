# https://zed.dev/docs/configuring-zed#lsp
# https://zed.dev/docs/configuring-zed#languages
# https://zed.dev/docs/languages/json
# https://zed.dev/docs/languages/biome
# https://zed.dev/extensions/biome
# https://biomejs.dev/reference/zed/
# https://biomejs.dev/internals/language-support/
{ pkgs, ... }:
{
  extensions = [ "biome" ];
  packages = [
    pkgs.biome
    pkgs.jsonfmt
  ];
  settings = {
    languages.JSON = {
      tab_size = 2;
      formatter = "language_server";
      language_servers = [
        "biome"
        "!json-language-server"
      ];
    };
    languages.JSONC = {
      tab_size = 2;
      formatter = "language_server";
      language_servers = [
        "biome"
        "!json-language-server"
      ];
    };
    lsp.biome = {
      binary = {
        path = "${pkgs.biome}/bin/biome";
        arguments = [ "lsp-proxy" ];
      };
      settings = { };
    };
    lsp.json-language-server = {
      settings = { };
    };
  };

}
