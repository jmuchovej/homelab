{
  rbn.programs._.development._.languages._.go.hm =
    { lib, pkgs, ... }:
    let
      inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

      go-lsp = mk-lsp {
        pkg = pkgs.gopls;
        args = [ "serve" ];
        extensions.".go" = "go";
        init.hints = {
          assignVariableTypes = true;
          compositeLiteralFields = true;
          compositeLiteralTypes = true;
          constantValues = true;
          functionTypeParameters = true;
          parameterNames = true;
          rangeVariableTypes = true;
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

      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          golang.go
        ];
        profiles.default.userSettings = { };
      };

      programs.zed-editor = {
        # https://zed.dev/docs/languages/go
        extensions = [ ];
        extraPackages = [
          go-lsp.pkg
          pkgs.golangci-lint
          pkgs.gotestsum
        ];
        userSettings = {
          lsp.gopls = go-lsp.zed;
          languages.Go = {
            tab_size = 2;
            formatter = "language_server";
            language_servers = [ "gopls" ];
          };
        };
      };

      programs.claude-code.lspServers = {
        go = go-lsp.claude;
      };
    };
}
