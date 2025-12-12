{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.rust;
  default-vscode = config.rebellion.editor.vscode or { };

  vsc-extensions = (with pkgs.open-vsx; [
    rust-lang.rust-analyzer
    vadimcn.vscode-lldb
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ ];
  zed-user-settings = { };
in {
  options.rebellion.development.rust = {
    enable = mkEnableOption "rust";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      cargo
      rustc
      cargo-binstall
      cargo-xtask
    ]);

    programs.vscode = mkIf config.rebellion.editor.vscode.enable {
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      extensions    = zed-extensions;
      extraPackages = [ pkgs.rust-analyzer ];
      userSettings  = zed-user-settings;
    };
  };
}
