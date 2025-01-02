{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) optionals mkIf mkEnableOption;
  inherit (pkgs.stdenv) isLinux;

  cfg = config.${namespace}.suites.desktop;
in
{
  options.${namespace}.suites.desktop = {
    enable = mkEnableOption "`desktop` configuration";
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; optionals isLinux [
      appimage-run
      # FIXME: broken nixpkgs
      # bitwarden
      bleachbit
      clac
      dropbox
      feh
      filelight
      fontpreview
      input-leap
      realvnc-vnc-viewer
      rustdesk-flutter
    ]);
  };
}
