{ den, ... }:
{
  rbn.programs._.development._.apps = {
    includes = [ (den.batteries.unfree [ "android-studio" ]) ];
    homeManager = { pkgs, lib, ... }: {
      home.packages = lib.mkIf pkgs.stdenv.isLinux (
        with pkgs;
        [
          kotlin
          swift
          android-studio
        ]
      );

      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          dart-code.dart-code
          dart-code.flutter
          zxh404.vscode-proto3
          sswg.swift-lang
        ];
        profiles.default.userSettings = { };
      };

      programs.zed-editor = {
        # https://zed.dev/docs/languages/dart
        # https://zed.dev/docs/languages/kotlin
        # https://zed.dev/docs/languages/swift
        extensions = [
          "swift"
          "kotlin"
        ];
        extraPackages = with pkgs; [
          # TODO: migrate to `kotlin-lsp` once on nixpkgs
          kotlin-language-server
          swiftlint
          swift-format
        ];
        userSettings = {
          lsp.kotlin-language-server = { };
          lsp.sourcekit-lsp = { };
        };
      };
    };

    darwin.homebrew = {
      brews = [
        "cocoapods"
        "xcodegen"
        "xcodes"
      ];
      casks = [ "android-studio" ];
    };
  };
}
