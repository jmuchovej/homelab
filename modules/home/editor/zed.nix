{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkForce
    mkMerge
    ;
  # inherit (builtins) concatStringsSep;

  cfg = config.rebellion.editor.zed;
  desktop = config.rebellion.desktop;
in
{
  options.rebellion.editor.zed = {
    enable = mkEnableOption "Zed";
    default = mkEnableOption "Zed as the default $EDTIOR";
  };

  config = mkIf (cfg.enable && desktop.enable) {
    home.sessionVariables.EDITOR = mkIf cfg.default (mkForce "zed --wait");

    home.shellAliases = {
      "zed" = "zeditor";
    };

    programs.zed-editor =
      let
        languages-lsps = import ./zed/languages-lsps.part.nix { inherit lib pkgs; };
      in
      {
        enable = true;
        package = pkgs.zed-editor;
        #! This is just to ensure we have the formatters!
        extraPackages = [
          pkgs.treefmt # Format the whole tree
        ]
        ++ languages-lsps.packages;
        extensions = [
          "catppuccin"
          "catppuccin-blur"
          "catppuccin-icons"
          "vscode-icons"
          "xml"
          "rainbow-csv"
          "just"
          "env"
          "comment"
        ]
        ++ languages-lsps.extensions;
        userSettings = mkMerge (
          [ ]
          ++ (import ./zed/base.part.nix)
          ++ (import ./zed/editor.part.nix)
          ++ (import ./zed/files.part.nix)
          ++ (import ./zed/fonts.part.nix)
          ++ (import ./zed/panels.part.nix)
          ++ (import ./zed/themes.part.nix)
          ++ (import ./zed/vim.part.nix)
          ++ (import ./zed/workspace.part.nix)
          ++ languages-lsps.settings
        );
      };
  };
}
