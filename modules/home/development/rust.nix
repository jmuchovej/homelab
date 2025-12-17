{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.rust;
  default-vscode = config.rebellion.editor.vscode or { };

  vsc-extensions = (
    with pkgs.open-vsx;
    [
      rust-lang.rust-analyzer
      vadimcn.vscode-lldb
    ]
  );
  vsc-user-settings = { };

  inherit (lib.rebellion.zed) mkzed-settings;
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
  options.rebellion.development.rust = {
    enable = mkEnableOption "rust";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (
      with pkgs;
      [
        cargo
        rustc
        cargo-binstall
        cargo-xtask
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
