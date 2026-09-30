{
  rbn.programs._.terminal._.treefmt.hm = { lib, pkgs, ... }: {
    home.packages = [ pkgs.treefmt ];

    programs.jujutsu = {
      settings = {
        fix.tools.treefmt = {
          enabled = true;
          command = lib.rbn.argv "treefmt --no-cache --stdin $path";
          patterns = [ "glob:**/*" ];
        };
      };
    };

    programs.zed-editor = {
      extraPackages = [ pkgs.treefmt ];
    };
  };
}
