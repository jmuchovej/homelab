{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.development.typst;
  default-vscode = config.${namespace}.editor.vscode or { };

  vsc-extensions = (with pkgs.open-vsx; [
    myriad-dreamin.tinymist
  ]);
  vsc-user-settings = {
    "[typst]" = {
      "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
    };
    "[typst-code]" = {
      "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
    };
  };

  zed-extensions    = [ "typst" ];
  zed-user-settings = { };
in {
  options.${namespace}.development.typst = {
    enable = mkEnableOption "typst";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      typst
      typstyle
      tinymist
    ]);

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      extensions    = vsc-extensions;
      userSettings  = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions    = zed-extensions;
      extraPackages = with pkgs; [ typstyle tinymist ];
      userSettings  = zed-user-settings;
    };
  };
}
