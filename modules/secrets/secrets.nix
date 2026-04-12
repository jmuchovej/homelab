{ inputs, ... }:
{
  flake-file.inputs = {
    sops-nix.url = "github:mic92/sops-nix";
  };

  den.default = {
    nixos =
      { host, ... }:
      {
        imports = [
          inputs.sops-nix.nixosModules.sops
        ];
        sops = {
          defaultSopsFile = ./hosts/${host}.sops.yaml;
          defaultSopsFormat = "yaml";
          age.keyFile = "/var/lib/secrets/sops/age/keys.txt";
        };
      };

    darwin =
      { host, ... }:
      {
        imports = [
          inputs.sops-nix.darwinModules.sops
        ];
        sops = {
          defaultSopsFile = ./hosts/${host}.sops.yaml;
          defaultSopsFormat = "yaml";
          age.keyFile = "/var/lib/secrets/sops/age/keys.txt";
        };
      };

    homeManager =
      { host, lib, ... }:
      {
        imports = [
          inputs.sops-nix.homeManagerModules.sops
        ];
        sops = {
          defaultSopsFile = lib.mkDefault ./users/${host.user.name}.sops.yaml;
          defaultSopsFormat = "yaml";
          age.keyFile = "/var/lib/secrets/sops/age/keys.txt";
        };
      };
  };
}
