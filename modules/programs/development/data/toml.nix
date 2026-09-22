## Shared by every language that ships a TOML manifest (python, julia, rust).
## Must stay a standalone aspect they `include` rather than a per-language
## definition: `lspServers.<name>.args` lists concatenate when two modules
## define the same server, which would spawn `tombi lsp lsp`.
{
  rbn.programs._.development._.data._.toml.hm =
    { lib, pkgs, ... }:
    let
      # https://github.com/tombi-toml/tombi/blob/main/docs/src/routes/docs/editors/zed-extension.mdx
      # https://tombi-toml.github.io/tombi/docs/editors/zed-extension
      toml-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.tombi;
        args = [ "lsp" ];
        extensions.".toml" = "toml";
      };
    in
    {
      home.packages = [ toml-lsp.pkg ];

      programs.zed-editor = {
        extensions = [ "tombi" ];
        extraPackages = [ toml-lsp.pkg ];
        userSettings = {
          file_types.TOML = [
            "mise.lock"
            "Cargo.lock"
          ];
          languages.TOML = {
            tab_size = 2;
            formatter = "language_server";
            language_servers = [ "tombi" ];
          };
          lsp.tombi = toml-lsp.zed;
        };
      };

      programs.claude-code.lspServers = {
        toml = toml-lsp.claude;
      };
    };
}
