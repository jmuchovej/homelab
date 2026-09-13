{
  rbn.programs._.development._.languages._.typst.hm =
    { lib, pkgs, ... }:
    let
      inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

      tinymist-lsp = mk-lsp {
        pkg = pkgs.tinymist;
        args = [ "lsp" ];
        extensions.".typ" = "typst";
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
    in
    {
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
            formatter = "language_server";
            language_servers = [ "tinymist" ];
          };
          lsp.tinymist = tinymist-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        typst = tinymist-lsp.claude;
      };
    };
}
