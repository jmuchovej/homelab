{
  __findFile,
  den,
  rbn-policies,
  ...
}:
{
  rbn.programs._.security = {
    macos.homebrew.casks = [ "gpg-suite" ];

    hm = { pkgs, ... }: {
      programs.gpg.enable = true;
      home.packages = with pkgs; [
        age
        sops
        ssh-to-age
      ];
    };

    _.onepassword = {
      # `op` and signature *verification* are wanted everywhere; the desktop app,
      # the agent socket it publishes, and the `op-ssh-sign` binary that ships
      # inside it are not. Splitting on that line rather than on the aspect keeps
      # servers holding the CLI.
      includes = [
        <rbn/programs/security/onepassword/cli>
        (rbn-policies.when-desktop "onepassword" <rbn/programs/security/onepassword/desktop>)
      ];

      _.cli = {
        includes = [ (den.batteries.unfree [ "1password-cli" ]) ];

        # Signing lives here, not in `_.desktop`: on a remote box the key is
        # reached through a forwarded agent, and ssh-keygen(1) handles that —
        # "the key used for signing … may refer to either a private key, or a
        # public key with the private half available via ssh-agent(1)". Git
        # hands it the public half from `user.signingkey`, the forwarded
        # `SSH_AUTH_SOCK` supplies the private half, and no 1Password binary
        # needs to exist locally. `_.desktop` only overrides `gpg.ssh.program`
        # to the app's `op-ssh-sign` where the app is actually installed.
        hm =
          { config, pkgs, ... }:
          let
            signing-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";
          in
          {
            home = {
              packages = [ pkgs._1password-cli ];
              file.".ssh/allowed_signers".text = "* ${signing-key}";
            };

            programs.git.settings = {
              gpg.format = "ssh";
              commit.gpgsign = true;
              tag.gpgsign = true;
              user.signingkey = signing-key;
            };

            programs.jujutsu.settings.signing = {
              behavior = "drop";
              backend = "ssh";
              key = signing-key;
              # Unset without `_.desktop`, and jj has no `gpg.ssh.program` to
              # inherit from — fall back to the same default git would use.
              backends.ssh.program = config.programs.git.settings.gpg.ssh.program or "ssh-keygen";
              git.sign-on-push = true;
            };
          };
      };

      _.desktop = {
        includes = [ (den.batteries.unfree [ "1password" ]) ];

        dock.app = "1Password.app";

        hm-macos = { config, pkgs, ... }: {
          home.file.".1password/agent.sock".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

          programs.git.settings.gpg.ssh.program =
            "${pkgs._1password-gui}/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        };

        hm-linux = { pkgs, ... }: {
          programs.git.settings.gpg.ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
        };

        # Only ever set where the 1Password app runs: on a remote host this
        # would clobber the agent socket sshd forwards in, which is precisely
        # what signing there depends on.
        hm = { pkgs, ... }: {
          home = {
            packages = [ pkgs._1password-gui ];
            sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
          };
        };

        os = { pkgs, ... }: {
          environment.systemPackages = [ pkgs._1password-gui ];
        };

        macos.homebrew.masApps = {
          # "1Password for Safari" = 1569813296;
        };
      };
    };

    _.proton = {
      includes = [
        <rbn/programs/security/proton/cli>
        (rbn-policies.when-desktop "proton" <rbn/programs/security/proton/desktop>)
      ];

      _.cli = {
        hm = { pkgs, ... }: {
          home.packages = [ pkgs.proton-pass-cli ];
        };
      };

      _.desktop = {
        hm = { pkgs, ... }: {
          # TODO: needs upstream nixpkg support for protonmail-desktop, protonmail-bridge,
          # protonvpn-cli, proton-pass
          home.packages = with pkgs; [
            proton-vpn
            proton-pass
            protonmail-desktop
          ];
        };
      };
    };
  };
}
