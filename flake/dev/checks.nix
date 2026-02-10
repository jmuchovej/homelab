{
  inputs,
  self,
  lib,
  ...
}:
{
  imports = lib.optional (inputs ? git-hooks-nix) inputs.git-hooks-nix.flakeModule;

  perSystem =
    { pkgs, ... }:
    {
      pre-commit = lib.mkIf (inputs ? git-hooks-nix) {
        check.enable = false;

        settings.hooks = {
          pre-commit-hook-ensure-sops.enable = true;
          treefmt.enable = true;
        };
      };

      # deploy-rs checks (linux-only, moved from flake/deploy.nix)
      checks = lib.optionalAttrs pkgs.stdenv.isLinux (
        self.inputs.deploy.lib.${pkgs.stdenv.hostPlatform.system}.deployChecks self.deploy
      );
    };
}
