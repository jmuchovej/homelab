{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.tools.bottom;
in {
  options.${namespace}.programs.tools.bottom = {
    enable = mkEnableOption "bottom";
  };

  config = mkIf cfg.enable {
    programs.bottom = {
      enable = true;
      package = pkgs.bottom;

      settings = {
        flags = {
          # https://clementtsang.github.io/bottom/nightly/configuration/config-file/flags/
          tree = true;
          group_processes = true;
          show_table_scroll_position = true;
        };

        row = [
          {
            ratio = 3;
            child = [
              {type = "cpu";}
              {type = "mem";}
              {type = "net";}
            ];
          }
          {
            ratio = 3;
            child = [
              {
                type = "proc";
                ratio = 1;
                default = true;
              }
            ];
          }
        ];
      };
    };
  };
}
