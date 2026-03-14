{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.shells.zsh";
  description = "`zsh`";
  config =
    { pkgs, ... }:
    {
      programs.zsh = {
        enable = true;
        autosuggestions.enable = true;
        enableCompletion = true;
      };

      environment.sessionVariables = {
        LC_ALL = "en_US.UTF-8";
        KEYTIMEOUT = 0;
      };

      environment.systemPackages = with pkgs; [
        nix-zsh-completions
      ];
    };
}
