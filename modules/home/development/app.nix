{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.app;
  default-vscode = config.rebellion.editor.vscode or { };

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
  options.rebellion.development.app = {
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

    programs.vscode = mkIf config.rebellion.editor.vscode.enable {
      profiles.default.extensions = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
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
