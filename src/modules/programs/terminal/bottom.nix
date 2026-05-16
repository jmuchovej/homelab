_: {
  rbn.programs._.terminal._.bottom.homeManager =
    { pkgs, ... }:
    {
      programs.bottom = {
        enable = true;
        package = pkgs.bottom;

        settings = {
          flags = {
            tree = true;
            group_processes = true;
            show_table_scroll_position = true;
          };

          row = [
            {
              ratio = 3;
              child = [
                { type = "cpu"; }
                { type = "mem"; }
                { type = "net"; }
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
