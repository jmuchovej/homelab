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

  cfg = config.${namespace}.development.go;
  default-vscode = config.${namespace}.editor.vscode or { };

  vsc-extensions = (
    with pkgs.open-vsx;
    [
      golang.go
    ]
  );
  vsc-user-settings = { };

  zed-extensions = [
    "gosum"
    "golangci-lint"
  ];
  zed-user-settings = {
    Go = {
      tab_size = 2;
    };
  };

in
{
  options.${namespace}.development.go = {
    enable = mkEnableOption "go";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (
      with pkgs;
      [
        go
        air
        gotools
        golangci-lint
        gotestsum
        gopls
      ]
    );

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = with pkgs; [
        gopls
        golangci-lint
        gotestsum
        gotools
      ];
      userSettings = zed-user-settings;
    };
  };
}
