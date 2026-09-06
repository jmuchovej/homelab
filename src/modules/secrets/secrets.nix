{ inputs, ... }:
{
  flake-file.inputs = {
    sops-nix.url = "github:mic92/sops-nix";
  };

  den.default = {
    os = { host, lib, ... }: {
      sops = {
        defaultSopsFile = lib.mkDefault ./hosts/${host.name}.sops.yaml;
        defaultSopsFormat = "yaml";
      };
    };

    nixos = {
      imports = [ inputs.sops-nix.nixosModules.sops ];
    };

    macos = {
      imports = [ inputs.sops-nix.darwinModules.sops ];
    };

    hm = { user, lib, ... }: {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops = {
        defaultSopsFile = lib.mkDefault ./users/${user.userName}.sops.yaml;
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
