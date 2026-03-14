{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "programs.tools.eza";
  description = "eza";
  config =
    { lib, ... }:
    {
      environment.systemPackages = [ pkgs.eza ];
      environment.shellAliases = {
        eza = "eza --group --group-directories-first --header --hyperlink --git --icons=auto";
        ls = "eza";
        ll = "eza -l";
        la = "eza -a";
        lt = "eza --tree";
        lla = "eza -la";
        tree = lib.mkForce "eza -T --icons=always";
      };
    };
}
