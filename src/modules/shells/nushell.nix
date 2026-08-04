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
          userSettings = {
            lsp = {
              nu = {
                binary = {
                  path = config.programs.nushell.package;
                  arguments = [
                    "--config"
                    "${config.programs.nushell.configDir}/config.nu"
                    "--lsp"
                  ];
                };
              };
            };
          };
        };
      };
  };
}
