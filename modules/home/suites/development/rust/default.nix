{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.rust;
  default-vscode = config.programs.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    rust-lang.rust-analyzer
    vadimcn.vscode-lldb
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ ];
  zed-user-settings = { };
in {
  options.${namespace}.suites.development.rust = {
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

    programs.vscode = mkIf config.programs.vscode.enable {
      extensions    = vsc-extensions;
      userSettings  = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.programs.zed-editor.enable {
      extensions    = zed-extensions;
      userSettings  = zed-user-settings;
    };
  };
}
