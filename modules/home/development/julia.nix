{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.julia;
  default-vscode = config.rebellion.editor.vscode or { };

  vsc-extensions = (
    with pkgs.open-vsx;
    [
      julialang.language-julia
    ]
  );
  vsc-user-settings = {
    "julia.symbolCacheDownload" = true;
    "terminal.integrated.commandsToSkipShell" = [
      "language-julia.interrupt"
    ];
  };

  # https://zed.dev/docs/languages/julia
  # https://github.com/JuliaEditorSupport/zed-julia
  inherit (lib.rebellion.zed) mkzed-settings;
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
  options.rebellion.development.julia = {
    enable = mkEnableOption "julia";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (
      with pkgs;
      [
        julia-bin
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
