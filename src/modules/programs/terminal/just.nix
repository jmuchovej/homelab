{
  rbn.programs._.terminal._.just.hm =
    { lib, pkgs, ... }:
    let
      just-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.just-lsp;
        extensions = {
          "Justfile" = "just";
          "justfile" = "just";
          ".just" = "just";
          ".justfile" = "just";
        };
      };
    in
    {
      home.packages = [
        pkgs.just
        just-lsp.pkg
      ];

      programs.zed-editor = {
        extensions = [ "just" ];
        extraPackages = [ just-lsp.pkg ];
        userSettings = {
          languages.Just = {
            tab_size = 2;
            formatter = "none";
            language_servers = [ "just-lsp" ];
          };
          lsp.just-lsp = just-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        just = just-lsp.claude;
      };
    };
}
