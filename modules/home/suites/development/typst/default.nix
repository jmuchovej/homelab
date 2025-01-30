{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.typst;
  default-vscode = config.programs.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    myriad-dreamin.tinymist
  ]);
  vsc-user-settings = {
    "[typst]" = {
      "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
    };
  };

  zed-extensions    = [ "typst" ];
  zed-user-settings = { };
in {
  options.${namespace}.suites.development.typst = {
    enable = mkEnableOption "typst";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      typst
      typstyle
      tinymist
    ]);

    programs.vscode = mkIf config.programs.vscode.enable {
      extensions    = vsc-extensions;
      userSettings  = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.programs.zed-editor.enable {
      extensions    = zed-extensions;
      extraPackages = with pkgs; [ typstyle tinymist ];
      userSettings  = zed-user-settings;
    };
  };
}
