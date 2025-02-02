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

  cfg = config.${namespace}.development.julia;
  default-vscode = config.${namespace}.editor.vscode.profiles.default or { };

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
  options.${namespace}.development.julia = {
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

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      extensions = vsc-extensions;
      userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = [ pkgs.julia-bin ];
      userSettings = zed-user-settings;
    };
  };
}
