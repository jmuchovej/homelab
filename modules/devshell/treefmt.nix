{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      config-file = ".config/treefmt.toml";

      # treefmt-nix used to generate these two; the toml names them by these names.
      treefmt-just = pkgs.writeShellApplication {
        name = "treefmt-just";
        runtimeInputs = [ pkgs.just ];
        text = ''
          for file in "$@"; do
            just --fmt --unstable --justfile "$file"
          done
        '';
      };
      treefmt-statix = pkgs.writeShellApplication {
        name = "treefmt-statix";
        runtimeInputs = [ pkgs.statix ];
        text = ''
          for file in "$@"; do
            statix fix --config .config/statix.toml "$file"
          done
        '';
      };

      # Every `command` named in .config/treefmt.toml, so a missing one is a bug here.
      formatters = with pkgs; [
        deadnix
        groovy
        keep-sorted
        nixfmt-rs
        npm-groovy-lint
        opentofu
        oxfmt
        oxipng
        ruff
        shfmt
        tombi
        treefmt-just
        treefmt-statix
        typos
      ];

      # `treefmt` on PATH (and `nix fmt`) always reads the working tree's config, so
      # editing .config/treefmt.toml needs no shell reload. The root is found by
      # walking up from the cwd rather than asking git: on a case-insensitive
      # filesystem git may answer with different casing than the cwd, and treefmt
      # then rejects every path as "not inside the tree root".
      treefmt = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [ pkgs.treefmt ] ++ formatters;
        text = ''
          root="$PWD"
          while [ ! -f "$root/${config-file}" ] && [ "$root" != / ]; do
            root="$(dirname "$root")"
          done
          if [ ! -f "$root/${config-file}" ]; then
            echo "treefmt: no ${config-file} above $PWD" >&2
            exit 1
          fi
          exec ${lib.getExe pkgs.treefmt} \
            --config-file "$root/${config-file}" --tree-root "$root" "$@"
        '';
      };
    in
    {
      formatter = treefmt;

      # npm-groovy-lint runs a local CodeNarc JVM server, which does not come up in
      # the build sandbox; the check therefore omits it and lets treefmt skip the
      # groovy formatter. Groovy formatting is still enforced by the dev shell and
      # pre-commit, where the server works.
      checks.treefmt =
        pkgs.runCommand "treefmt-check"
          {
            nativeBuildInputs = [
              pkgs.treefmt
            ]
            ++ lib.subtractLists [ pkgs.npm-groovy-lint pkgs.groovy ] formatters;
          }
          ''
            cp -r ${self} src
            chmod -R u+w src
            cd src
            export HOME="$TMPDIR"
            treefmt --config-file ${config-file} --tree-root . \
              --no-cache --ci --allow-missing-formatter
            touch "$out"
          '';

      # Consumed by devShells.default via inputsFrom: the formatters stay on PATH
      # for editors, and `treefmt` is the wrapper above.
      devShells.formatting = pkgs.mkShell {
        packages = [ treefmt ] ++ formatters;
      };
    };
}
