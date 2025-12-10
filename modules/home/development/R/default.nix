{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkPackageOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.development.R;
  default-vscode = config.${namespace}.editor.vscode or { };

  default-packages = (with pkgs.rPackages; [
    # Tidyverse and friends
    tidyverse tidymodels pastecs
    # Document Writing
    quarto
    # Language Server
    languageserver
  ]);

  R       = cfg.package.override { packages = default-packages; };
  # RStudio = cfg.rstudio-package.override { packages = default-packages; };

  vsc-extensions = (with pkgs.open-vsx; [
    reditorsupport.r
  ]);
  vsc-user-settings = { };

  zed-extensions    = [ "r" ];
  zed-user-settings = { };
in {
  # FIXME: R appears to be broken due to some issues with `r-curl`???
  options.${namespace}.development.R = {
    enable  = mkEnableOption "R";
    package = mkPackageOption pkgs "rWrapper" { };
    rstudio = { package = mkPackageOption pkgs "rstudioWrapper" { }; };
    vscode  = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    home.packages = [ R ];

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions    = zed-extensions;
      userSettings  = zed-user-settings;
    };
  };
}
