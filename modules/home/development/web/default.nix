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

  cfg = config.${namespace}.development.web;
  default-vscode = config.${namespace}.editor.vscode.profiles.default or { };

  vsc-extensions = with pkgs.open-vsx; [
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
  ];
  vsc-user-settings = {
    # "[astro]"
  };

  zed-extensions = [
    "astro"
    "biome"
    "vue"
    "marksman"
  ];
  zed-user-settings = {
    languages.JavaScript = {
      tab_size = 2;
      formatter = "biome";
    };
    languages.TypeScript = {
      tab_size = 2;
      formatter = "biome";
    };
    languages.HTML = {
      tab_size = 2;
      formatter = "biome";
    };
    languages.Astro = {
      tab_size = 2;
      formatter = "biome";
    };
    languages."Vue.js" = {
      tab_size = 2;
      formatter = "biome";
    };
    languages.TSX = {
      tab_size = 2;
      formatter = "biome";
    };
    languages.CSS = {
      tab_size = 2;
      formatter = "biome";
    };
  };
in
{
  options.${namespace}.development.web = {
    enable = mkEnableOption "javascript";
    vscode = mkopt-vscode vsc-extensions vsc-user-settings;
  };

  config = mkIf cfg.enable {
    programs.bun = {
      enable = true;
      enableGitIntegration = true;
    };

    home.packages = with pkgs; [
      biome
      prettierd
    ];

    programs.vscode = mkIf config.${namespace}.editor.vscode.enable {
      extensions = vsc-extensions;
      userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.${namespace}.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = with pkgs; [
        biome
        prettierd
      ];
      userSettings = zed-user-settings;
    };
  };
}
