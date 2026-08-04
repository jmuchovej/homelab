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
        # `_`-prefixed directory is excluded and `leafs ./_zed` would return an
        # empty list. Overriding it replaces that filter wholesale.
        #
        # One arg set covers the tree because every part takes `...`: the files
        # at the root want `{ lib, ... }`, the ones under `languages-lsps/` want
        # `{ pkgs, ... }`, and both tolerate the other.
        parts = lib.pipe import-tree [
          (i: i.initFilter (p: lib.hasSuffix ".nix" (toString p)))
          (i: i.map (p: import p { inherit lib pkgs; }))
          (i: i.leafs ./_zed)
        ];

        settings = merge-deep (map (p: p.settings or { }) parts);

        lsp-packages = lib.unique (lib.concatMap (p: p.packages or [ ]) parts);
        lsp-extensions = lib.unique (lib.concatMap (p: p.extensions or [ ]) parts);
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
          extraPackages = [ pkgs.treefmt ] ++ lsp-packages;
          extensions = [
            "xml"
            "rainbow-csv"
            "just"
            "env"
            "comment"
          ]
          ++ lsp-extensions;
          userSettings = settings;
          userKeymaps = [ ];
        };
      };
  };
}
