{ __findFile, ... }:
{
  rbn.programs._.development._.languages._.julia = {
    includes = [ <rbn/programs/development/data/toml> ];

    hm =
      { lib, pkgs, ... }:
      let
        inherit (lib)
          replaceString
          mapAttrsToList
          mapAttrs
          concatStringsSep
          ;
        inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

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
          # "1.13" = pkgs.julia_113-bin;
        };

        julia-lsp = mk-lsp {
          pkg = pkgs.julia-bin.withPackages [
            "LanguageServer"
            "SymbolServer"
          ];
          extensions.".jl" = "julia";
          # `symserver_store_path` must be writable: SymbolServer's default is a
          # `store/` dir inside its own package, which under nix is the read-only
          # depot in /nix/store (mkdir EACCES on first index, server exits).
          args = [
            "-e"
            ''using LanguageServer, SymbolServer; runserver(stdin, stdout, LanguageServer.choose_env(), "", nothing, joinpath(homedir(), ".julia", "symbolstorev5"))''
          ];
        };

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
          extraPackages = [ julia-lsp.pkg ];
          userSettings = {
            languages.Julia = {
              tab_size = 4;
              formatter = "language_server";
            };
            lsp.julia = julia-lsp.zed;
            # lsp.jetls = julia-lsp.zed;
          };
        };

        programs.claude-code.lspServers = {
          julia = julia-lsp.claude;
        };
      };
  };
}
