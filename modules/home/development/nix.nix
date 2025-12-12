{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.nix;
  default-vscode = config.rebellion.editor.vscode or { };

  vsc-extensions = with pkgs.open-vsx; [
    jnoortheen.nix-ide
    arrterian.nix-env-selector
  ];
  vsc-user-settings = { };

  zed-extensions = [ "nix" ];
  zed-user-settings = {
    languages.Nix = {
      tab_size = 2;
      language_servers = [
        "nixd"
        "!nil"
      ];
      formatter = {
        external = {
          command = "nixfmt";
          arguments = [
            "--quiet"
            "--"
          ];
        };
      };
    };
  };
in
{
  options.rebellion.development.nix = {
    enable = mkEnableOption "nix";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
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
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = with pkgs; [
        nixd
        nil
      ];
      userSettings = zed-user-settings;
    };
  };
}
