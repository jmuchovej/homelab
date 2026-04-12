{ den, ... }:
{
  rbn.programs._.security = {
    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "gpg-suite" ];
      };

    homeManager =
      { pkgs, ... }:
      {
        programs.gpg.enable = true;
        home.packages = with pkgs; [
          age
          sops
          ssh-to-age
        ];
      };

    provides = {
      onepassword = {
        includes = [ (den.provides.unfree [ "1password-cli" ]) ];

        homeManager =
          { pkgs, ... }:
          {
            home.packages = [ pkgs._1password-cli ];
          };

        darwin =
          { host, lib, ... }:
          lib.mkIf host.homebrew.enable {
            homebrew.casks = [ "1password" ];
          };
      };
    };
  };
}
