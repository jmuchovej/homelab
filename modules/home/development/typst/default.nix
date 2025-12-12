{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.typst;
  default-vscode = config.rebellion.editor.vscode or { };

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
  options.rebellion.development.typst = {
    enable = mkEnableOption "typst";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      typst
      typstyle
      tinymist
    ]);

    programs.vscode = mkIf config.rebellion.editor.vscode.enable {
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      extensions    = zed-extensions;
      extraPackages = with pkgs; [ typstyle tinymist ];
      userSettings  = zed-user-settings;
    };
  };
}
