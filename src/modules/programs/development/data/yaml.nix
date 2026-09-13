{ __findFile, ... }: {
  rbn.programs._.development._.data._.yaml.hm =
    { lib, pkgs, ... }:
    let
      inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

      yaml-lsp = mk-lsp {
        pkg = pkgs.yaml-language-server;
        args = [ "--stdio" ];
        extensions = {
          ".yaml" = "yaml";
          ".yml" = "yaml";
        };
      };
    in
    {
      home.packages = [ yaml-lsp.pkg ];

      programs.zed-editor = {
        extraPackages = [
          pkgs.yamlfmt
          yaml-lsp.pkg
        ];
        extensions = [ ];
        userSettings = {
          file_types.YAML = [
            "pixi.lock"
          ];
          languages.YAML = {
            tab_size = 2;
            formatter = "none";
            language_servers = [ "yaml-language-server" ];
          };
          lsp.yaml-language-server = {
            settings = {
              "yaml.keyOrdering" = false;
              "yaml.format.singleQuote" = false;
              "yaml.format.trailingComma" = true;
            };
          };
        };
      };

      programs.claude-code.lspServers = {
        yaml = yaml-lsp.claude;
      };
    };
}
