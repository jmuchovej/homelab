_: {
  rbn.programs._.development._.go.homeManager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;

      vsc-extensions = with pkgs.open-vsx; [
        golang.go
      ];
      vsc-user-settings = { };

      # https://zed.dev/docs/languages/go
      zed = {
        extensions = [ ];
        extraPackages = with pkgs; [
          gopls
          golangci-lint
          gotestsum
        ];
        userSettings = {
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
        golangci-lint
        gotestsum
        gopls
      ];

      programs.vscode = mkIf (config.programs.vscode.enable or false) {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
