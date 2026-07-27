{
  rbn.programs._.development._.typst.homeManager = { pkgs, ... }: {
    home.packages = with pkgs; [
      typst
      tinymist
      typstyle
    ];

    programs.vscode = {
      profiles.default.extensions = with pkgs.open-vsx; [
        myriad-dreamin.tinymist
      ];
      profiles.default.userSettings = {
        "[typst]" = {
          "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
        };
        "[typst-code]" = {
          "editor.wordSeparators" = "`~!@#$%^&*()=+[{]}\\|;:'\",.<>/?";
        };
      };
    };

    programs.zed-editor = {
      # https://github.com/zed-extensions/typst
      extensions = [ "typst" ];
      extraPackages = with pkgs; [
        tinymist
        typstyle
      ];
      userSettings = {
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
  };
}
