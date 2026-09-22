{
  rbn.programs._.terminal._.ripgrep.hm = _: {
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
