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

  cfg = config.rebellion.development.go;
  default-vscode = config.rebellion.editor.vscode or { };

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
  options.rebellion.development.go = {
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

    programs.vscode = mkIf config.rebellion.editor.vscode.enable {
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
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
