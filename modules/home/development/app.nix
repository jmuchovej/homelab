{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.app";
  config =
    {
      cfg,
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mkzed-settings;

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

      # https://zed.dev/docs/languages/dart
      # https://zed.dev/docs/languages/kotlin
      # https://zed.dev/docs/languages/swift
      zed = mkzed-settings {
        extensions = [
          # https://github.com/zed-extensions/dart
          "dart"
          # https://github.com/zed-extensions/swift
          "swift"
          # https://github.com/zed-extensions/kotlin
          "kotlin"
        ];
        packages = with pkgs; [
          flutter
          # TODO: migrate to `kotlin-lsp` once on nixpkgs
          kotlin-language-server
          swiftlint
          swift-format
        ];
        settings = {
          languages.Dart = {
            tab_size = 2;
            formatter = "auto";
          };
          lsp.dart = {
            binary = {
              arguments = [
                "language-server"
                "--protocol=lsp"
              ];
            };
            settings = {
              lineLength = 120;
            };
          };
          lsp.kotlin-language-server = { };
          lsp.sourcekit-lsp = { };
        };
      };
    in
    {
      home.packages = (
        with pkgs;
        [
          flutter
          kotlin
          swift
        ]
      );

      programs.vscode = mkIf config.rebellion.editor.vscode.enable {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
