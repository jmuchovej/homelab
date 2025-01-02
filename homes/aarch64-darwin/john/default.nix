{ config, lib, namespace, ...  }: let
  inherit (lib) mkDefault;
  inherit (lib.${namespace}) enabled disabled;
in {
  rebellion = {
    user = {
      inherit (config.snowfallorg.user) name;
      enable = true;
    };

    suites = {
      common      = enabled;
      development = {
        enable      = true;
        app         = enabled;
        web         = enabled;
        go          = enabled;
        julia       = enabled;
        nix         = enabled;
        python      = enabled;
        R           = disabled;
        rust        = disabled;
        typst       = enabled;
      };
      desktop     = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
