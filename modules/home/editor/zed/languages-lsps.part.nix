# https://zed.dev/docs/configuring-zed#lsp
# https://zed.dev/docs/configuring-zed#languages
{ lib, pkgs, ... }:
let
  inherit (lib.lists) flatten;
  yaml = import ./languages-lsps/yaml.part.nix { inherit pkgs; };
  json = import ./languages-lsps/json.part.nix { inherit pkgs; };
  toml = import ./languages-lsps/toml.part.nix { inherit pkgs; };
  md = import ./languages-lsps/markdown.part.nix { inherit pkgs; };
  langs = [
    yaml
    json
    toml
    md
  ];

  extensions = flatten (map (lang: lang.extensions) langs);
  packages = flatten (map (lang: lang.packages) langs);
  settings = flatten (map (lang: lang.settings) langs);
in
{
  inherit extensions packages settings;
}
