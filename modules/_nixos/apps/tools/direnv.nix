{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "apps.tools.direnv";
  description = "direnv";
  config = _: {
    rebellion.home.extra-options = {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
      };
    };

    environment.sessionVariables.DIRENV_LOG_FORMAT = ""; # Blank so direnv will shut up
  };
}
