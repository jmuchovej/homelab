{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.rebellion.programs.shells.zsh;
in {
  options.rebellion.programs.shells.zsh = {
    enable = mkEnableOption "`zsh`";
  };

  config = mkIf cfg.enable {
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
