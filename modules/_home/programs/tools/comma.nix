{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.terminal.tools.comma";

  config =
    { pkgs, config, ... }:
    let
      inherit (config.rebellion) shell;
    in
    {
      programs.nix-index-database.comma.enable = true;

      programs.nix-index = {
        enable = true;
        package = pkgs.nix-index;

        enableBashIntegration = shell.bash.enable;
        enableFishIntegration = shell.fish.enable;
        enableZshIntegration = shell.zsh.enable;

        # link nix-index database to ~/.cache/nix-index
        symlinkToCacheHome = true;
      };
    };
}
