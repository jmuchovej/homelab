{ inputs, ... }:
{
  rbn.programs._.editors._.zed = {
    dock.app = "Zed.app";

    # `inputs` is a flake-parts arg, not a home-manager module arg — closing over
    # it from the file scope is the only way in (see `ai-tools/claude.nix`).
    hm =
      { lib, pkgs, ... }:
      let
        inherit (inputs) import-tree;

        merge-deep = lib.foldl' lib.recursiveUpdate { };

        # One walk over the whole `_zed` tree instead of two `import-dir` calls.
        #
        # `initFilter` is required, not cosmetic: import-tree's default filter is
        # `andNot (hasInfix "/_") (hasSuffix ".nix")`, so every path under a
        # `_`-prefixed directory is excluded and `leaves ./_zed` would return an
        # empty list. Overriding it replaces that filter wholesale.
        #
        # One arg set covers the tree because every part takes `...`: the files
        # at the root want `{ lib, ... }`, the ones under `languages-lsps/` want
        # `{ pkgs, ... }`, and both tolerate the other.
        parts = import-tree (i: i.map (p: import p { inherit lib pkgs; })) (i: i.leaves ./_zed);

        settings = merge-deep (map (p: p.settings or { }) parts);

        lsp-packages = lib.unique (lib.concatMap (p: p.packages or [ ]) parts);
        lsp-extensions = lib.unique (lib.concatMap (p: p.extensions or [ ]) parts);
        keybinds = lib.unique (lib.concatMap (p: p.keybinds or [ ]) parts);
      in
      {
        home.shellAliases.zed = "zeditor";

        programs.zed-editor = {
          enable = true;
          package = pkgs.zed-editor;
          enableMcpIntegration = true;
          # TODO: make this contingent on whether i'm on a server/cluster
          # defaultEditor = true;
          # TODO: make this contingent on whether i'm on a server/cluster
          installRemoteServer = true;
          extraPackages =
            lsp-packages
            ++ (with pkgs; [
              treefmt
              jsonfmt
              marksman
              tombi
              yamlfmt
              yaml-language-server
            ]);
          extensions = lsp-extensions ++ [
            "xml"
            "rainbow-csv"
            "just"
            "env"
            "comment"
            "tombi"
            "marksman"
          ];
          userSettings = lib.recursiveUpdate settings {
            prettier.allowed = false;
            languages = {
              YAML = {
                tab_size = 2;
                formatter = "language_server";
                language_servers = [ "yaml-language-server" ];
              };
              TOML = {
                tab_size = 2;
                formatter = "language_server";
                language_servers = [ "tombi" ];
              };
              Markdown = {
                tab_size = 2;
                formatter = "language_server";
                language_servers = [ "marksman" ];
              };
              JSON = {
                tab_size = 2;
                formatter = "language_server";
                language_servers = [ "json-language-server" ];
              };
              JSONC = {
                tab_size = 2;
                formatter = "language_server";
                language_servers = [ "json-language-server" ];
              };
              Just = {
                tab_size = 2;
              };
            };
            lsp = {
              json-language-server = { };
              marksman = { };
              # https://github.com/tombi-toml/tombi/blob/main/docs/src/routes/docs/editors/zed-extension.mdx
              # https://tombi-toml.github.io/tombi/docs/editors/zed-extension
              tombi = {
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
              yaml-language-server = {
                settings = {
                  yaml.keyOrdering = false;
                  format.singleQuote = false;
                };
              };
            };
          };
          userKeymaps = keybinds;
        };
      };
  };
}
