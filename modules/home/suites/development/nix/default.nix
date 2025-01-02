{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode enabled;

  cfg = config.${namespace}.suites.development.nix;
  default-vscode = config.programs.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    jnoortheen.nix-ide
    arrterian.nix-env-selector
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ "julia" ];
  zed-user-settings = {
    "lsp" = {
      "Nix" = {
        "language_servers" = [ "nil" ];
        "formatter" = {
          "external" = {
            "command" = "alejandra";
            "arguments" = ["--quiet" "--"];
          };
        };
      };
    };
  };
in {
  options.${namespace}.suites.development.nix = {
    enable = mkEnableOption "nix";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = (with pkgs; [
      nixd
      nil
      nixfmt-rfc-style
      nix-prefetch-git
      hydra-check
      nixpkgs-hammering
      nixpkgs-lint-community
      nixpkgs-review
      nix-update
      nix-output-monitor
      alejandra
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
