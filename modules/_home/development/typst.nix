{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "development.typst";
  config =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mk-zed-settings;

      vsc-extensions = with pkgs.open-vsx; [
        myriad-dreamin.tinymist
      ];
      vsc-user-settings = {
        "[typst]" = {
          "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
        };
        "[typst-code]" = {
          "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
        };
      };

      zed = mk-zed-settings {
        # https://github.com/zed-extensions/typst
        extensions = [ "typst" ];
        packages = with pkgs; [
          typst
          tinymist
          typstyle
        ];
        settings = {
          languages.Typst = {
            tab_size = 2;
            language_servers = [ "tinymist" ];
          };
          lsp.tinymist = {
            settings = {
              lint = {
                enabled = true;
                when = "onType";
              };
              compileStatus = "enable";
              exportPdf = "onSave";
              outputPath = "\$dir/\$name";
              formatterIndentSize = 2;
              formatterMode = "typstyle";
            };
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        typst
        typstyle
        tinymist
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
