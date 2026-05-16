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
        includes = [
          (den.batteries.unfree [
            "1password-cli"
            "1password"
          ])
        ];

        homeManager =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            inherit (pkgs.stdenv) isDarwin;
            op-ssh-sign =
              "${pkgs._1password-gui}"
              + (if isDarwin then "/Applications/1Password.app/Contents/MacOS" else "/bin")
              + "/op-ssh-sign";

            signing-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";
          in
          {
            home = {
              packages = [ pkgs._1password-cli ];
              sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
              file = {
                ".ssh/allowed_signers".text = "* ${signing-key}";
                ".1password/agent.sock" = lib.mkIf isDarwin {
                  source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
                };
              };
            };

            programs.git.settings = {
              gpg.format = "ssh";
              gpg.ssh.program = op-ssh-sign;
              commit.gpgsign = true;
              tag.gpgsign = true;
              user.signingkey = signing-key;
            };

            programs.jujutsu.settings.signing = {
              behavior = "drop";
              backend = "ssh";
              key = signing-key;
              backends.ssh.program = op-ssh-sign;
              git.sign-on-push = true;
            };
          };

        os = { pkgs, ... }: {
          environment.systemPackages = [ pkgs._1password-gui ];
        };

        darwin = { host, lib, ... }: {
          homebrew.masApps = lib.mkIf (host.meta.uses-homebrew or false) {
            # "1Password for Safari" = 1569813296;
          };
        };
      };
    };
  };
}
