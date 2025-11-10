{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.development.app;
  default-vscode = config.${namespace}.editor.vscode or { };

  vsc-extensions = (
    with pkgs.open-vsx;
    [
      dart-code.dart-code
      dart-code.flutter
      zxh404.vscode-proto3
      sswg.swift-lang
    ]
  );
  vsc-user-settings = { };

  zed-extensions = [
    "dart"
    "proto"
    "swift"
  ];
  zed-user-settings = { };
in
{
  options.${namespace}.development.app = {
    enable = mkEnableOption "apps";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (
      with pkgs;
      [
        flutter
        kotlin
        protobuf
      ]
    );

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      extensions = vsc-extensions;
      userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = with pkgs; [
        flutter
        protobuf
        kotlin-language-server
        swiftlint
        swift-format
      ];
      userSettings = zed-user-settings;
    };
  };
}
