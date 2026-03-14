{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "shell.bash";
  config =
    { pkgs, ... }:
    {
      programs.bash = {
        enable = true;
        enableCompletion = true;

        historyControl = [ "ignoredups" ];
        historyFileSize = 100000;

        shellOptions = [
          "autocd"
          "histappend"
          "direxpand"
          "checkwinsize"
          "extglob"
          "globstar"
          "checkjobs"
        ];
      };

      home.sessionVariables = { };

      home.packages = with pkgs; [
        nix-bash-completions
      ];

      home.file = { };
    };
}
