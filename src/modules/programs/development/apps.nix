{ den, inputs, ... }:
{
  flake-file.inputs = {
    homebrew-fvm.url = "github:leoafarias/fvm";
    homebrew-fvm.flake = false;
  };

  rbn.programs._.development._.apps = {
    includes = [ (den.batteries.unfree [ "android-studio" ]) ];
    homeManager =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        inherit (lib) mkIf;

        vsc-extensions = with pkgs.open-vsx; [
          dart-code.dart-code
          dart-code.flutter
          zxh404.vscode-proto3
          sswg.swift-lang
        ];
        vsc-user-settings = { };

        # https://zed.dev/docs/languages/dart
        # https://zed.dev/docs/languages/kotlin
        # https://zed.dev/docs/languages/swift
        zed = {
          extensions = [
            "dart"
            "swift"
            "kotlin"
          ];
          extraPackages = with pkgs; [
            flutter
            # TODO: migrate to `kotlin-lsp` once on nixpkgs
            kotlin-language-server
            swiftlint
            swift-format
          ];
          userSettings = {
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
        home.packages = lib.mkIf pkgs.stdenv.isLinux (
          with pkgs;
          [
            flutter
            kotlin
            swift
            android-studio
          ]
        );

        programs.vscode = mkIf (config.programs.vscode.enable or false) {
          profiles.default.extensions = vsc-extensions;
          profiles.default.userSettings = vsc-user-settings;
        };

        programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
          inherit (zed) extensions extraPackages userSettings;
        };
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew = {
          brews = [
            "cocoapods"
            "xcodegen"
            "xcodes"
            "leoafarias/fvm/fvm"
          ];
          casks = [
            "flutter"
            "android-studio"
          ];
        };

        nix-homebrew.taps."leoafarias/fvm" = inputs.homebrew-fvm;
      };
  };
}
