{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) enabled;
in {
  rebellion = {
    user = {
      inherit (config.snowfallorg.user) name;
    };

    nix = enabled;

    ssh = {
      authorized-keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
      ];
    };

    development = enabled;
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}

