{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.bash;
in {
  options.${namespace}.shell.bash = {
    enable = mkEnableOption "`bash`";
  };

  config = mkIf cfg.enable {
    programs.bash = {
      enable = true;
      enableCompletion = true;

      historyControl = ["ignoredups"];
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

    home.sessionVariables = {};

    home.packages = with pkgs; [
      nix-bash-completions
    ];

    home.file = {};
  };
}
