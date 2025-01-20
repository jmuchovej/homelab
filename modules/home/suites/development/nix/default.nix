{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.nix;
  default-vscode = config.programs.vscode.profiles.default or { };

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
  options.${namespace}.suites.development.nix = {
    enable = mkEnableOption "nix";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
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
    ];

    programs.vscode = mkIf config.programs.vscode.enable {
      extensions = vsc-extensions;
      userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.programs.zed-editor.enable {
      extensions = zed-extensions;
      extraPackages = with pkgs; [
        nixd
        nil
      ];
      userSettings = zed-user-settings;
    };
  };
}
