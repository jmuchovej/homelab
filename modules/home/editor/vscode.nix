{
  pkgs,
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkForce;
  inherit (builtins) concatStringsSep;

  cfg = config.rebellion.editor.vscode;
  desktop = config.rebellion.desktop;

  # desired-fonts = ["MonoLisa" "JetBrainsMono Nerd Font" "JetBrainsMono" "Fira Code" "monospace"];
  # https://github.com/microsoft/vscode/issues/84018#issuecomment-550176878
  font-ligature-map = {
    #! Retrieved from: https://monaspace.githubnext.com/#code-ligatures
    "MonaSpice" = ["calt" "ss01" "ss02" "ss03" "ss04" "ss05" "ss06" "ss07" "ss08" "ss09" "liga"];
    #! Painfully determined via: https://www.monolisa.dev/playground
    "MonaLisaNerdFont" = ["ss04" "zero" "ss11" "ss13" "ss15" "ss16" "ss17"];
    "JetBrainsMonoNerdFont" = [];
    "FireCodeNerdFont" = [];
  };
  ligatures = font-ligature-map."MonaSpice";
  ligatures-str = concatStringsSep ", " (map (s: "'${s}'") ligatures);
  desired-fonts = ["MonaSpiceNe Nerd Font"];
  desired-fonts-str = concatStringsSep ", " desired-fonts;
in {
  options.rebellion.editor.vscode = {
    enable = mkEnableOption "Visual Studio Code";
    default = mkEnableOption "VSCode as default $EDTIOR";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    home.sessionVariables.EDITOR = mkIf cfg.default (mkForce "vscode --wait");

    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      # https://raw.githubusercontent.com/nix-community/nix-vscode-extensions/master/data/cache/open-vsx-latest.json
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
          # aaron-bond.better-comments
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
        # Editor settings
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
        "editor.rulers" = [88 90 120 160];
        "editor.unicodeHighlight.ambiguousCharacters" = false;

        "editor.wordWrap" = "bounded";
        "editor.wrappingIndent" = "deepIndent";
        "editor.wrappingStrategy" = "advanced";

        "editor.lineNumbers" = "relative";

        "editor.find.autoFindInSelection" = "multiline";
        "search.globalFindClipboard" = true;

        # Theming
        "workbench.iconTheme" = "material-icon-theme";
        "workbench.preferredDarkColorTheme" = "Catppuccin Mocha";
        "workbench.preferredLightColorTheme" = "Catppuccin Latte";
        "window.systemColorTheme" = "auto";
        "window.autoDetectColorScheme" = true;

        # vim
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
        "[svg]" = {
          "editor.defaultFormatter" = "jock.svg";
        };
      };
    };
  };
}
