_: {
  rbn.programs._.development._.julia.homeManager =
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
        julialang.language-julia
      ];
      vsc-user-settings = {
        "julia.symbolCacheDownload" = true;
        "terminal.integrated.commandsToSkipShell" = [
          "language-julia.interrupt"
        ];
      };

      # https://zed.dev/docs/languages/julia
      # https://github.com/JuliaEditorSupport/zed-julia
      zed = mk-zed-settings {
        extensions = [ "julia" ];
        packages = with pkgs; [ julia-bin ];
        settings = {

          lsp.julia = {
          };
          languages.Julia = {
            tab_size = 4;
            formatter = "language_server";
          };
        };
      };
    in
    {
      home.packages = with pkgs; [
        julia-bin
      ];

      programs.vscode = mkIf (config.programs.vscode.enable or false) {
        profiles.default.extensions = vsc-extensions;
        profiles.default.userSettings = vsc-user-settings;
      };

      programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
