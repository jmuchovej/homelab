{
  config,
  pkgs,
  lib,
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

  inherit (lib.rebellion.zed) mkzed-settings;
  # https://zed.dev/docs/languages/go
  zed = mkzed-settings {
    extensions = [ ];
    packages = with pkgs; [
      gopls
      golangci-lint
      gotestsum
      gotools
    ];
    settings = {
      lsp.gopls = {
        initialization_options = {
          hints = {
            assignVariableTypes = true;
            compositeLiteralFields = true;
            compositeLiteralTypes = true;
            constantValues = true;
            functionTypeParameters = true;
            parameterNames = true;
            rangeVariableTypes = true;
          };
        };
      };
      languages.Go = {
        tab_size = 2;
        language_servers = [ "gopls" ];
      };
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
      profiles.default.extensions = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      inherit (zed) extensions extraPackages userSettings;
    };
  };
}
