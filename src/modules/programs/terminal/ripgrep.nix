_: {
  rbn.programs._.terminal._.ripgrep.homeManager = {
    programs.ripgrep = {
      enable = true;
      arguments = [
        "--max-columns-preview"
        "--hidden"
        "--smart-case"
        "--follow"
      ];
    };
  };
}
