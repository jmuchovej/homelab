{ inputs, ... }:
let
  sops-config = {
    defaultSopsFile = ./secrets.sops.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/secrets/sops/age/keys.txt";
  };
in
{
  flake-file.inputs.sops-nix.url = "github:mic92/sops-nix";

  rbn.secrets.nixos = {
    imports = [ inputs.sops-nix.nixosModules.sops ];
    sops = sops-config;
  };

  rbn.secrets.darwin = {
    imports = [ inputs.sops-nix.darwinModules.sops ];
    sops = sops-config;
  };

  rbn.secrets.homeManager =
    { pkgs, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];
      sops = sops-config;
      home.packages = [ pkgs.sops ];
    };
}
