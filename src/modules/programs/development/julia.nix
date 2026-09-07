{
  rbn.programs._.development._.julia.hm =
    { lib, pkgs, ... }:
    let
      inherit (lib)
        replaceString
        mapAttrsToList
        mapAttrs
        concatStringsSep
        ;

      tools = [
        "AbbreviatedStackTraces"
        "BenchmarkTools"
        "OhMyREPL"
        "Revise"
      ];

      tool-envs = mapAttrs (_: jl: (jl.withPackages tools).projectAndDepot) {
        "1.10" = pkgs.julia_110-bin;
        "1.11" = pkgs.julia_111-bin;
        "1.12" = pkgs.julia_112-bin;
      };

      julia-lsp = pkgs.julia-bin.withPackages [
        "LanguageServer"
        "SymbolServer"
      ];
      julia-lsp-cmd = lib.getExe julia-lsp;
      julia-lsp-args = [
        "-e"
        ''"using LanguageServer, SymbolServer; runserver()"''
      ];

      to-dict = ver: env: ''${"    "}v"${ver}" => "${env}",'';
      tool-table = concatStringsSep "\n" (mapAttrsToList to-dict tool-envs);
      startup-jl = builtins.readFile ./startup.jl;
    in
    {
      home.packages = [ pkgs.julia-bin ];
      home.file.".julia/config/startup.jl".text = replaceString "# @@tool-envs@@" tool-table startup-jl;

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
        extraPackages = [ pkgs.julia-bin ];
        userSettings = {
          lsp.julia = {
            binary.path = julia-lsp-cmd;
            binary.args = julia-lsp-args;
          };
          languages.Julia = {
            tab_size = 4;
            formatter = "language_server";
          };
        };
      };

      programs.claude-code.lspServers = {
        julia = {
          command = julia-lsp-cmd;
          args = julia-lsp-args;
          extensionToLanguage.".jl" = "julia";
        };
      };
    };
}
