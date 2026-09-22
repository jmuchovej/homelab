{
  rbn.shells._.nushell = {
    os = { pkgs, ... }: {
      environment.shells = [ pkgs.nushell ];
    };

    hm =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        nu = config.programs.nushell;
        nu-lsp = lib.rbn.mk-lsp {
          pkg = nu.package;
          args = [
            "--config"
            "${nu.configDir}/config.nu"
            "--lsp"
          ];
          extensions = {
            ".nu" = "nu";
          };
        };
      in
      {
        home.shell.enableNushellIntegration = true;

        programs.nushell = {
          enable = true;
          shellAliases = lib.filterAttrs (_k: v: !lib.hasInfix " && " v) config.home.shellAliases;
          settings = {
            use_ls_colors = true;
          };
          plugins = with pkgs.nushellPlugins; [
            formats # from/to plist, eml, ics, ini, vcf
            gstat # git status as structured data (fast, for prompts)
            polars # dataframes
            query # query json/xml/html/web
            skim # fuzzy finder over structured data
          ];
        };

        programs.zed-editor = {
          extensions = [ "nu" ];
          extraPackages = [ nu-lsp.pkg ];
          userSettings = {
            lsp.nu = nu-lsp.zed;
          };
        };

        programs.claude-code.lspServers = {
          nu = nu-lsp.claude;
        };
      };
  };
}
