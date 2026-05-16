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
          {
            config,
            lib,
            pkgs,
            ...
          }:
          {
            home.packages = [ pkgs._1password-cli ];

            # Use 1Password as the SSH agent everywhere.
            home.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";

            # macOS puts the agent socket under Group Containers; symlink it
            # to ~/.1password/agent.sock so the same SSH_AUTH_SOCK works on
            # both platforms. Linux's 1Password writes there directly.
            home.file.".1password/agent.sock" = lib.mkIf pkgs.stdenv.isDarwin {
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
            };
          };

        darwin =
          { host, lib, ... }:
          lib.mkIf host.homebrew.enable {
            homebrew.casks = [ "1password" ];
            homebrew.masApps = {
              # "1Password for Safari" = 1569813296;
            };
          };
      };
    };
  };
}
