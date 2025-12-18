{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.nix";
  config =
    {
      cfg,
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mkzed-settings;

      vsc-extensions = with pkgs.open-vsx; [
        jnoortheen.nix-ide
        # arrterian.nix-env-selector
      ];
      vsc-user-settings = { };

      zed = mkzed-settings {
        # https://github.com/zed-extensions/nix
        extensions = [ "nix" ];
        packages = with pkgs; [
          nixd
          nixfmt
          nix-output-monitor
        ];
        settings = {
          languages.Nix = {
            tab_size = 2;
            language_servers = [
              "nixd"
              "!nil"
            ];
          };
          lsp.nixd = {
            initialization_options = {
              formatting.command = [
                "nixfmt"
                "--quiet"
                "--"
              ];
            };
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        nixd
        nil
        nixfmt
        nix-prefetch-git
        hydra-check
        nixpkgs-hammering
        nixpkgs-lint-community
        nixpkgs-review
        nix-update
        nix-output-monitor
        alejandra
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
