_: {
  rbn.programs._.terminal._.eza.homeManager =
    { lib, pkgs, ... }:
    {
      programs.eza = {
        enable = true;
        package = pkgs.eza;

        extraOptions = [
          "--group"
          "--group-directories-first"
          "--header"
          "--hyperlink"
          "--git-ignore"
        ];

        git = true;
        icons = "auto";
        colors = "auto";
      };

      home.shellAliases = {
        tree = lib.mkForce "lt";
      };
    };
}
