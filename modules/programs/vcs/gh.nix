_: {
  rbn.programs._.vcs._.gh.homeManager =
    { pkgs, ... }:
    {
      programs.gh = {
        enable = true;
        package = pkgs.gh;
        settings = {
          protocol = "ssh";
          prompt = "enabled";
          aliases = { };
        };
      };

      programs.gh-dash = {
        enable = true;
        package = pkgs.gh-dash;
      };
    };
}
