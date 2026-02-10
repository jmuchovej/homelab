{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.rust";
  config =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mkzed-settings;

      vsc-extensions = with pkgs.open-vsx; [
        rust-lang.rust-analyzer
        vadimcn.vscode-lldb
      ];
      vsc-user-settings = { };

      # https://zed.dev/docs/languages/rust
      zed = mkzed-settings {
        extensions = [ ];
        packages = with pkgs; [
          rust-analyzer
        ];
        settings = {
          languages.Rust = {
            tab_size = 2;
          };
          lsp.rust-analyzer = {
            initialization_options = {
              checkOnSave = true;
              check = {
                workspace = false;
              };
            };
            settings = {
              enable_lsp_tasks = true;
            };
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        cargo
        rustc
        cargo-binstall
        cargo-xtask
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
