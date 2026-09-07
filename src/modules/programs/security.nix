{
  __findFile,
  inputs,
  den,
  rbn-policies,
  ...
}:
let
  sops-file = kind: name: "${inputs.self}/secrets/${kind}/${name}.sops.yaml";
in
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
      includes = [
        <rbn/programs/security/onepassword/cli>
        (rbn-policies.when-desktop "onepassword" <rbn/programs/security/onepassword/desktop>)
      ];

      _.cli = {
        includes = [ (den.batteries.unfree [ "1password-cli" ]) ];

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

        hm = { pkgs, ... }: {
          home = {
            packages = [ pkgs._1password-gui ];
            sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
          };

          mcp-servers.settings.servers = {
            "1password" = {
              type = "stdio";
              command = "1password-mcp";
            };
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

    _.sops = {
      nixos = { host, pkgs, ... }: {
        environment.systemPackages = with pkgs; [
          age
          sops
          ssh-to-age
        ];

        sops = {
          defaultSopsFile = sops-file "hosts" host.hostname;

          age = {
            sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
            generateKey = false;
          };
        };
      };

      hm =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          home = config.home.homeDirectory;
        in
        {
          home.packages = with pkgs; [
            age
            sops
            ssh-to-age
          ];

          sops = {
            defaultSopsFile = sops-file "users" config.home.username;
            defaultSopsFormat = "yaml";

            age = {
              keyFile = lib.mkDefault "${home}/.config/sops/age/keys.txt";
              sshKeyPaths = [
                "${home}/.ssh/id_ed25519"
                "/etc/ssh/ssh_host_ed25519_key"
              ];
            };

            secrets."nix-access-tokens" = { };
          };
        };
    };
  };
}
