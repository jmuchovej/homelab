{
  rbn.programs._.terminal._.treefmt.hm = { pkgs, ... }: {
    home.packages = [ pkgs.treefmt ];

    programs.jujutsu = {
      settings = {
        fix.tools.treefmt = {
          enabled = true;
          command = [
            "treefmt"
            "--no-cache"
            "--stdin"
            "$path"
          ];
          patterns = [ "glob:**/*" ];
        };
      };
    };

    programs.zed-editor = {
      extraPackages = [ pkgs.treefmt ];
    };
  };
}
