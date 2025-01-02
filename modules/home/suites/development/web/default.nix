{ config, pkgs, lib, namespace, ...}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.${namespace}) mkopt-vscode;

  cfg = config.${namespace}.suites.development.web;
  default-vscode = config.programs.vscode.profiles.default or {};

  vsc-extensions = (with pkgs.open-vsx; [
    astro-build.astro-vscode
    oven.bun-vscode
    unifiedjs.vscode-mdx
    davidanson.vscode-markdownlint
    bradlc.vscode-tailwindcss
    stylelint.vscode-stylelint
    esbenp.prettier-vscode
    vue.volar
    antfu.slidev
    dbaeumer.vscode-eslint
  ]);
  vsc-user-settings = {
    # "[astro]"
  };

  zed-extensions    = [ "astro" "biome" "vue" "marksman" ];
  zed-user-settings = { };

in {
  options.${namespace}.suites.development.web = {
    enable = mkEnableOption "javascript";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    programs.bun = {
      enable                = true;
      enableGitIntegration  = true;
    };

    home.packages = (with pkgs; [
      biome prettierd
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
