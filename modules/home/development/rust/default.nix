{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.development.rust;
  default-vscode = config.${namespace}.editor.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    rust-lang.rust-analyzer
    vadimcn.vscode-lldb
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ ];
  zed-user-settings = { };
in {
  options.${namespace}.development.rust = {
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

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      extensions    = vsc-extensions;
      userSettings  = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions    = zed-extensions;
      extraPackages = [ pkgs.rust-analyzer ];
      userSettings  = zed-user-settings;
    };
  };
}
