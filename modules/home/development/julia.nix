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

  zed-extensions = [ "julia" ];
  zed-user-settings = {
    Julia = {
      tab_size = 4;
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
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = [ pkgs.julia-bin ];
      userSettings = zed-user-settings;
    };
  };
}
