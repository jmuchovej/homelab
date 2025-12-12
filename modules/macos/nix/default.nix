{
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}:
let
  inherit (lib) mkIf mkForce;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.nix;
  #! https://github.com/LnL7/nix-darwin/issues/852
  #! According to ️^, the using `nix.linux-builder` with `nix*-unstable` doesn't work...
  # linux-builder-package = inputs.nixpkgs-stable.legacyPackages.${system}.darwin.linux-builder;
in
{
  imports = [ (get-file "modules/shared/nix/default.nix") ];

  config = mkIf cfg.enable {
    nix = {
      # Options that aren't supported through nix-darwin
      extraOptions = ''
        # bail early on missing cache hits
        connect-timeout = 10
        keep-going = true
      '';

      # gc.user = config.rebellion.user.name;
      # optimise.user = config.rebellion.user.name;
    };
  };
}
