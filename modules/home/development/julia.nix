{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.julia";
  config =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mkzed-settings;

      vsc-extensions = with pkgs.open-vsx; [
        julialang.language-julia
      ];
      vsc-user-settings = {
        "julia.symbolCacheDownload" = true;
        "terminal.integrated.commandsToSkipShell" = [
          "language-julia.interrupt"
        ];
      };

      # https://zed.dev/docs/languages/julia
      # https://github.com/JuliaEditorSupport/zed-julia
      zed = mkzed-settings {
        extensions = [ "julia" ];
        packages = with pkgs; [ julia-bin ];
        settings = {

          lsp.julia = {
          };
          languages.Julia = {
            tab_size = 4;
            formatter = "language_server";
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        julia-bin
      ];

      programs.vscode = mkIf config.rebellion.editor.vscode.enable {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
