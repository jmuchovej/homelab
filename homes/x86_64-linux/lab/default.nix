{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) enabled;
in {
  rebellion = {
    user = enabled // {
      inherit (config.snowfallorg.user) name;
    };

    nix = enabled;

    programs = {
      tools = {
        ssh = enabled // {
          authorized-keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
          ];
        };
      };
    };

    suites = {
      common = enabled;
      development = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
