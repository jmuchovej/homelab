{ inputs, ... }:
let
  secrets = "${inputs.self}/secrets";
in
{
  flake-file.inputs = {
    sops-nix.url = "github:mic92/sops-nix";
  };

  den.default = {
    os = { host, lib, ... }: {
      sops = {
        defaultSopsFile = lib.mkDefault "${secrets}/hosts/${host.name}.sops.yaml";
        defaultSopsFormat = "yaml";

        age = {
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          generateKey = false;
        };
      };
    };

    nixos = {
      imports = [ inputs.sops-nix.nixosModules.sops ];
    };

    macos = {
      imports = [ inputs.sops-nix.darwinModules.sops ];
    };

    hm = { config, lib, ... }: {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops = {
        defaultSopsFile = lib.mkDefault "${secrets}/users/${config.home.username}.sops.yaml";
        defaultSopsFormat = "yaml";
      };
    };

    hm-macos = { lib, ... }: {
      home.activation.sops-nix = lib.mkForce (
        lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
          /bin/launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.sops-nix"
        ''
      );
    };
  };
}
