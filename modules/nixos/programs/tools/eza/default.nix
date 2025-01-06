{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkForce getExe;

  cfg = config.${namespace}.programs.tools.eza;
in {
  options.${namespace}.programs.tools.eza = {
    enable = mkEnableOption "eza";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.eza ];
    environment.shellAliases = {
      eza   = "eza --group --group-directories-first --header --hyperlink --git --icons=auto";
      ls    = "eza";
      ll    = "eza -l";
      la    = "eza -a";
      lt    = "eza --tree";
      lla   = "eza -la";
      tree  = mkForce "eza -T --icons=always";
    };
  };
}
