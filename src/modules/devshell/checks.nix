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
            # no-cache (default: true) uses mtime-based change detection which
            # races with pre-commit's stash/restore cycle, causing false positives.
            settings.no-cache = false;
          };
        };
      };

      # deploy-rs checks (linux-only)
      checks = lib.optionalAttrs pkgs.stdenv.isLinux (
        self.inputs.deploy.lib.${pkgs.stdenv.hostPlatform.system}.deployChecks self.deploy
      );
    };
}
