{
  rbn.programs._.development._.languages._.dart.hm =
    { lib, pkgs, ... }:
    let
      inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

      dart-lsp = mk-lsp {
        pkg = pkgs.dart;
        args = [
          "language-server"
          "--protocol=lsp"
        ];
        extensions.".dart" = "dart";
      };
    in
    {
      home.packages = [
        pkgs.dart
        dart-lsp.pkg
      ];

      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          dart-code.dart-code
        ];
        profiles.default.userSettings = { };
      };

      # https://zed.dev/docs/languages/dart
      programs.zed-editor = {
        extensions = [ "dart" ];
        extraPackages = [ dart-lsp.pkg ];
        userSettings = {
          languages.Dart = {
            format_on_save = "on";
            code_actions_on_format = {
              "source.organizeImports" = true;
              "source.fixAll" = true;
            };
          };
          lsp.dart = dart-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        dart = dart-lsp.claude;
      };
    };
}
