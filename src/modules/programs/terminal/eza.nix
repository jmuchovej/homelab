{
  rbn.programs._.terminal._.eza.hm = { lib, ... }: {
    programs.eza = {
      enable = true;

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
