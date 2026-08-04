{
  inputs,
  self,
  lib,
  ...
}:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem = { pkgs, ... }: {
    pre-commit = {
      check.enable = false;

      settings.hooks = {
        pre-commit-hook-ensure-sops.enable = true;
        treefmt = {
          enable = true;
          settings.no-cache = false;
        };
        check-k8s-schemas = {
          enable = true;
          entry = lib.getExe (pkgs.callPackage ./_git-hooks/check-k8s-schemas.nix { });
          files = "^src/kubernetes/.*\\.ya?ml$";
          # ConfigMap payloads (blueprints, HA config) and kustomize patches
          # (partial manifests, `patch-*` by convention) are not validatable
          # standalone
          excludes = [
            "^src/kubernetes/.*/blueprints/"
            "^src/kubernetes/apps/home-automation/home-assistant/app/config/"
            # app-config payloads mounted via configMapGenerator (home-ops
            # `resources/` convention) — not k8s manifests
            "^src/kubernetes/.*/resources/"
            "/patch-[^/]*\\.ya?ml$"
            # sops-encrypted manifests aren't validatable standalone (ENC[…]
            # values + a `sops` block); ensure-sops covers their encryption
            "\\.sops\\.yaml$"
          ];
        };
      };
    };

    checks = {
      # Gate the co-located `denTest` suites in `flake.tests` behind
      # `nix flake check` (which does not know the `tests` output).
      # Compared here in pure eval rather than by running nix-unit in a
      # derivation — that would need every flake input re-provided inside
      # the build sandbox. `just test` runs nix-unit for readable diffs.
      den-tests =
        let
          collect =
            path: attrs:
            lib.concatLists (
              lib.mapAttrsToList (
                name: value:
                let
                  here = path ++ [ name ];
                in
                if value ? expr then
                  [ (value // { name = lib.concatStringsSep "." here; }) ]
                else
                  collect here value
              ) attrs
            );

          tests = collect [ ] self.tests;
          failed = lib.filter (t: t ? expected && t.expr != t.expected) tests;

          show = t: ''
            FAIL ${t.name}
              expr:     ${lib.generators.toPretty { multiline = false; } t.expr}
              expected: ${lib.generators.toPretty { multiline = false; } t.expected}
          '';
        in
        pkgs.runCommand "den-tests"
          {
            report = lib.concatMapStrings show failed;
            passAsFile = [ "report" ];
          }
          ''
            if [ -s "$reportPath" ]; then
              cat "$reportPath"
              echo "${toString (builtins.length failed)}/${toString (builtins.length tests)} den tests failed"
              exit 1
            fi
            echo "${toString (builtins.length tests)}/${toString (builtins.length tests)} den tests passed"
            touch $out
          '';
    }
    # deploy-rs checks (linux-only)
    // lib.optionalAttrs pkgs.stdenv.isLinux (
      self.inputs.deploy.lib.${pkgs.stdenv.hostPlatform.system}.deployChecks self.deploy
    );
  };
}
