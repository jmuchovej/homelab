{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption mkForce getExe;

  cfg = config.${namespace}.programs.tools.eza;
  # Get the `eza` from `home-manager`
  eza-bin = getExe config.programs.eza.package;
in
{
  options.${namespace}.programs.tools.eza = {
    enable = mkEnableOption "eza";
  };

  config = lib.mkIf cfg.enable {
    programs.eza = {
      enable = true;
      package = pkgs.eza;

      extraOptions = [
        "--group"
        "--group-directories-first"
        "--header"
        "--hyperlink"
        "--git-ignore"
      ];

      # TODO does this work on linux-arm64 yet?
      git   = true;
      icons = "auto";
    };

    home.shellAliases = {
      # home-manager already configures `ls`, `ll`, `la`, `lt`, and `lla`
      tree = mkForce "eza -T --icons=always";
    };
  };
}
