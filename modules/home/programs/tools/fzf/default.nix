{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption getExe;

  cfg = config.${namespace}.programs.tools.fzf;

  fd-bin = getExe pkgs.fd;
in
{
  options.${namespace}.programs.tools.fzf = {
    enable = mkEnableOption "fzf.";
  };

  config = mkIf cfg.enable {
    programs.fzf = {
      enable = true;

      defaultCommand = "${fd-bin} --type=f --hidden --exclude=.git";
      defaultOptions = [
        "--layout=reverse" # Top-first.
        "--exact" # Substring matching by default, `'`-quote for subsequence matching.
        "--bind=alt-p:toggle-preview,alt-a:select-all"
        "--multi"
        "--no-mouse"
        "--info=inline"

        # Style and widget layout
        "--ansi"
        "--with-nth=1.."
        "--pointer=' '"
        "--pointer=' '"
        "--header-first"
        "--border=rounded"
      ];

      tmux = {
        enableShellIntegration = true;
      };
    };
  };
}
