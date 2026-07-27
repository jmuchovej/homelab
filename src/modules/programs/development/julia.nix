{
  rbn.programs._.development._.julia.homeManager = { pkgs, ... }: {
    home.packages = with pkgs; [
      julia-bin
    ];

    programs.vscode = {
      profiles.default.extensions = with pkgs.open-vsx; [
        julialang.language-julia
      ];
      profiles.default.userSettings = {
        "julia.symbolCacheDownload" = true;
        "terminal.integrated.commandsToSkipShell" = [
          "language-julia.interrupt"
        ];
      };
    };

    # https://zed.dev/docs/languages/julia
    # https://github.com/JuliaEditorSupport/zed-julia
    programs.zed-editor = {
      extensions = [ "julia" ];
      extraPackages = with pkgs; [ julia-bin ];
      userSettings = {

        lsp.julia = {
        };
        languages.Julia = {
          tab_size = 4;
          formatter = "language_server";
        };
      };
    };
  };
}
