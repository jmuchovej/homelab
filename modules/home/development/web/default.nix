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

  cfg = config.rebellion.development.web;
  default-vscode = config.rebellion.editor.vscode or { };

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
  options.rebellion.development.web = {
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

    programs.vscode = mkIf config.rebellion.editor.vscode.enable {
      profiles.default.extensions   = vsc-extensions;
      profiles.default.userSettings = vsc-user-settings;
    };

    programs.zed-editor = mkIf config.rebellion.editor.zed.enable {
      extensions = zed-extensions;
      extraPackages = with pkgs; [
        biome
        prettierd
      ];
      userSettings = zed-user-settings;
    };
  };
}
