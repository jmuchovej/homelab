_: {
  rbn.programs._.terminal._.zoxide.homeManager =
    { pkgs, ... }:
    {
      programs.zoxide = {
        enable = true;
        package = pkgs.zoxide;
        options = [ "--cmd z" ];
      };
    };
}
