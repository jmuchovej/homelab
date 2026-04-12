_: {
  rbn.programs._.editors._.vscode.homeManager =
    { lib, pkgs, ... }:
    let
      inherit (builtins) concatStringsSep;

      ligatures = [
        "calt"
        "ss01"
        "ss02"
        "ss03"
        "ss04"
        "ss05"
        "ss06"
        "ss07"
        "ss08"
        "ss09"
        "liga"
      ];
      ligatures-str = concatStringsSep ", " (map (s: "'${s}'") ligatures);
      desired-fonts = [ "MonaSpiceNe Nerd Font" ];
      desired-fonts-str = concatStringsSep ", " desired-fonts;
    in
    {
      programs.vscode = {
        enable = true;
        package = pkgs.vscode;

        profiles.default.extensions =
          (with pkgs.open-vsx; [
            streetsidesoftware.code-spell-checker
            vscodevim.vim
            jock.svg
            gruntfuggly.todo-tree
            vscode-icons-team.vscode-icons
            mkhl.direnv
            mikestead.dotenv
            catppuccin.catppuccin-vsc
            edwinhuish.better-comments-next
            tomoki1207.pdf
            redhat.vscode-xml
            redhat.vscode-yaml
            mechatroner.rainbow-csv
            tamasfe.even-better-toml
            signageos.signageos-vscode-sops
          ])
          ++ (with pkgs.vscode-marketplace; [
            amodio.toggle-excluded-files
          ]);

        profiles.default.userSettings = {
          "explorer.excludeGitIgnore" = true;
          "workbench.editor.highlightModifiedTabs" = true;

          "editor.fontLigatures" = ligatures-str;
          "editor.fontFamily" = desired-fonts-str;
          "editor.fontWeight" = 500;
          "terminal.integrated.fontFamily" = desired-fonts-str;
          "terminal.integrated.fontLigatures" = ligatures-str;

          "editor.tabSize" = 2;
          "editor.indentSize" = "tabSize";
          "editor.minimap.enabled" = false;
          "editor.rulers" = [
            88
            90
            120
            160
          ];
          "editor.unicodeHighlight.ambiguousCharacters" = false;

          "editor.wordWrap" = "bounded";
          "editor.wrappingIndent" = "deepIndent";
          "editor.wrappingStrategy" = "advanced";
          "editor.lineNumbers" = "relative";
          "editor.find.autoFindInSelection" = "multiline";
          "search.globalFindClipboard" = true;

          "workbench.iconTheme" = "material-icon-theme";
          "workbench.preferredDarkColorTheme" = "Catppuccin Mocha";
          "workbench.preferredLightColorTheme" = "Catppuccin Latte";
          "window.systemColorTheme" = "auto";
          "window.autoDetectColorScheme" = true;

          "vim.camelCaseMotion.enable" = true;
          "vim.changeWordIncludesWhitespace" = true;
          "vim.easymotion" = true;
          "vim.foldfix" = true;
          "vim.highlightedyank.enable" = true;
          "vim.hlsearch" = true;
          "vim.leader" = " ";
          "vim.replaceWithRegister" = true;
          "vim.sneak" = true;
          "vim.sneakUseIgnorecaseAndSmartcase" = true;

          "[svg]"."editor.defaultFormatter" = "jock.svg";
        };
      };
    };
}
