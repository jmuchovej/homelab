{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.bat";
  description = "bat";
  config =
    { pkgs, ... }:
    {
      programs.bat = {
        enable = true;
        extraPackages = with pkgs.bat-extras; [
          batdiff
          batgrep
          batman
          batpipe
          batwatch
          prettybat
        ];
      };

      environment.shellAliases = {
        cat = "bat";
      };
    };
}
