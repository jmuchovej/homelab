{
  rbn.programs._.development._.go.homeManager = { pkgs, ... }: {
    home.packages = with pkgs; [
      go
      air
      golangci-lint
      gotestsum
      gopls
    ];

    programs.vscode = {
      profiles.default.extensions = with pkgs.open-vsx; [
        golang.go
      ];
      profiles.default.userSettings = { };
    };

    programs.zed-editor = {
      # https://zed.dev/docs/languages/go
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
  };
}
