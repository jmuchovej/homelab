{ __findFile, ... }:
{
  rbn.programs._.development._.languages._.rust = {
    includes = [ <rbn/programs/development/data/toml> ];

    hm =
      { lib, pkgs, ... }:
      let
        rust-lsp = lib.rbn.mk-lsp {
          pkg = pkgs.rust-analyzer;
          extensions.".rs" = "rust";
          init = {
            checkOnSave = true;
            check.workspace = false;
          };
        };
      in
      {
        home.packages = with pkgs; [
          cargo
          rustc
          cargo-binstall
          cargo-workspaces
        ];

        programs.vscode = {
          profiles.default.extensions = with pkgs.open-vsx; [
            rust-lang.rust-analyzer
            vadimcn.vscode-lldb
          ];
          profiles.default.userSettings = { };
        };

        # https://zed.dev/docs/languages/rust
        programs.zed-editor = {
          extensions = [ ];
          extraPackages = [ rust-lsp.pkg ];
          userSettings = {
            languages.Rust = {
              tab_size = 2;
              formatter = "language_server";
              language_servers = [ "rust-analyzer" ];
            };
            lsp.rust-analyzer = rust-lsp.zed // {
              settings.enable_lsp_tasks = true;
            };
          };
        };

        programs.claude-code.lspServers = {
          rust = rust-lsp.claude;
        };
      };
  };
}
