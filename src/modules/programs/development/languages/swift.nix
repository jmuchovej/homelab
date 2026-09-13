{
  rbn.programs._.development._.languages._.swift = {
    hm-linux = { pkgs, ... }: {
      home.packages = [ pkgs.swift ];
    };

    hm =
      { lib, pkgs, ... }:
      let
        inherit (import ../_lsp.nix { inherit lib; }) mk-lsp;

        swift-lsp = mk-lsp {
          pkg = pkgs.sourcekit-lsp;
          extensions.".swift" = "swift";
        };
      in
      {
        programs.vscode = {
          profiles.default.extensions = with pkgs.open-vsx; [
            sswg.swift-lang
          ];
          profiles.default.userSettings = { };
        };

        # https://zed.dev/docs/languages/swift
        programs.zed-editor = {
          extensions = [ "swift" ];
          extraPackages = [
            swift-lsp.pkg
            pkgs.swiftlint
            pkgs.swift-format
          ];
          userSettings = {
            languages.Swift = {
              tab_size = 2;
              formatter = "language_server";
              language_servers = [ "sourcekit-lsp" ];
            };
            lsp.sourcekit-lsp = swift-lsp.zed;
          };
        };

        programs.claude-code.lspServers = {
          swift = swift-lsp.claude;
        };
      };
  };
}
