_:
{
  rbn.programs._.editors._.zed.homeManager =
    { lib, pkgs, ... }:
    let
      inherit (lib.rebellion) import-dir attrs;

      languages-lsps = import-dir ./zed/languages-lsps { inherit lib pkgs; };
      zed = import-dir ./zed { inherit lib; };
      settings = attrs.merge-deep [
        zed.settings
        languages-lsps.settings
      ];
    in
    {
      rebellion.dock.entries = [
        {
          name = "Zed.app";
          source = "hm";
          group = "editors";
          order = 510;
        }
      ];

      home.shellAliases.zed = "zeditor";

      programs.zed-editor = {
        enable = true;
        package = pkgs.zed-editor;
        extraPackages = [
          pkgs.treefmt
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
        userSettings = settings;
        userKeymaps = [ ];
      };
    };
}
