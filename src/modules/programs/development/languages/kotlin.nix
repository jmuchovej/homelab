{
  rbn.programs._.development._.languages._.kotlin.hm =
    { lib, pkgs, ... }:
    let
      # TODO: migrate to `kotlin-lsp` once on nixpkgs
      kotlin-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.kotlin-language-server;
        extensions = {
          ".kt" = "kotlin";
          ".kts" = "kotlin";
          ".ktm" = "kotlin";
        };
      };
    in
    {
      home.packages = [
        pkgs.kotlin
        kotlin-lsp.pkg
      ];

      # https://zed.dev/docs/languages/kotlin
      programs.zed-editor = {
        extensions = [ "kotlin" ];
        extraPackages = [ kotlin-lsp.pkg ];
        userSettings = {
          file_types.Kotlin = [ ];
          languages.Kotlin = {
            format_on_save = "on";
            code_actions_on_format = {
              "source.organizeImports" = true;
              "source.fixAll" = true;
            };
          };
          lsp.kotlin-language-server = kotlin-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        kotlin = kotlin-lsp.claude;
      };
    };
}
