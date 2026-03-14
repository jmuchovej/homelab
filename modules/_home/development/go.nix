{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.go";
  config =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mk-zed-settings;

      vsc-extensions = with pkgs.open-vsx; [
        golang.go
      ];
      vsc-user-settings = { };

      # https://zed.dev/docs/languages/go
      zed = mk-zed-settings {
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
      home.packages = with pkgs; [
        go
        air
        gotools
        golangci-lint
        gotestsum
        gopls
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
