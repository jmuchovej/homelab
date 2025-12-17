{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.rebellion) mkopt-vscode;

  cfg = config.rebellion.development.R;
  default-vscode = config.rebellion.editor.vscode or { };

  default-packages = (
    with pkgs.rPackages;
    [
      # Tidyverse and friends
      tidyverse
      tidymodels
      pastecs
      # Document Writing
      quarto
      # Language Server
      languageserver
    ]
  );

  R = cfg.package.override { packages = default-packages; };
  # RStudio = cfg.rstudio-package.override { packages = default-packages; };

  vsc-extensions = (
    with pkgs.open-vsx;
    [
      reditorsupport.r
    ]
  );
  vsc-user-settings = { };

  # https://zed.dev/docs/languages/r
  inherit (lib.rebellion.zed) mkzed-settings;
  zed = mkzed-settings {
    extensions = [
      "r"
      "air"
    ];
    packages = [
      pkgs.air-formatter
      (cfg.package.override {
        packages = with pkgs.rPackages; [
          air
          languageserver
          lintr
        ];
      })
    ];
    settings = {
      lsp.air = {
      };
      languages.R = {
        tab_size = 2;
        language_servers = [ "air" ];
      };
    };
  };
in
{
  # FIXME: R appears to be broken due to some issues with `r-curl`???
  options.rebellion.development.R = {
    enable = mkEnableOption "R";
    package = mkPackageOption pkgs "rWrapper" { };
    rstudio = {
      package = mkPackageOption pkgs "rstudioWrapper" { };
    };
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = [ R ];

    programs.vscode = mkIf config.rebellion.editor.vscode.enable {
      profiles.default.extensions = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      inherit (zed) extensions extraPackages userSettings;
    };
  };
}
