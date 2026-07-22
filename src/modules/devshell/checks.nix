{
  inputs,
  self,
  lib,
  ...
}:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
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
            ];
          };
        };
      };

      # deploy-rs checks (linux-only)
      checks = lib.optionalAttrs pkgs.stdenv.isLinux (
        self.inputs.deploy.lib.${pkgs.stdenv.hostPlatform.system}.deployChecks self.deploy
      );
    };
}
