{ config, pkgs, lib, namespace, ...}:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.app;
  default-vscode = config.programs.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    dart-code.dart-code
    dart-code.flutter
    zxh404.vscode-proto3
    sswg.swift-lang
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ "dart" "proto" "swift" ];
  zed-user-settings = { };
in {
  options.${namespace}.suites.development.app = {
    enable = mkEnableOption "apps";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      flutter
    ]);

    programs.vscode = mkIf config.programs.vscode.enable {
      extensions    = vsc-extensions;
      userSettings  = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.programs.zed-editor.enable {
      extensions    = zed-extensions;
      userSettings  = zed-user-settings;
    };
  };
}
