{ config, pkgs, lib, namespace, ...}: let
  inherit (builtins) fetchGit;
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.go;
  default-vscode = config.programs.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    golang.go
  ]);
  vsc-user-settings = { };

  zed-extensions = [ "gosum" "golangci-lint" ];
  zed-user-settings = { };

in {
  options.${namespace}.suites.development.go = {
    enable = mkEnableOption "go";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      go
      air
      gotools
      golangci-lint
      gotestsum
      gopls
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
