{ inputs, ... }:
{
  flake-file.inputs = {
    sops-nix.url = "github:mic92/sops-nix";
  };

  den.default = {
    # NOTE: `age.keyFile` is intentionally unset across all three classes.
    # sops-nix derives the age identity from each host's SSH ed25519 key via
    # `sshKeyPaths` (system: `/etc/ssh/ssh_host_ed25519_key`; user: their own
    # `~/.ssh/id_ed25519`). Pinning a `keyFile` to a path that may not exist
    # makes sops-install-secrets bail before the SSH-derived key gets a chance.
    nixos =
      { host, lib, ... }:
      {
        imports = [ inputs.sops-nix.nixosModules.sops ];
        sops = {
          defaultSopsFile = lib.mkDefault ./hosts/${host.name}.sops.yaml;
          defaultSopsFormat = "yaml";
        };
      };

    darwin =
      { host, lib, ... }:
      {
        imports = [ inputs.sops-nix.darwinModules.sops ];
        sops = {
          defaultSopsFile = lib.mkDefault ./hosts/${host.name}.sops.yaml;
          defaultSopsFormat = "yaml";
        };
      };

    homeManager =
      { host, lib, ... }:
      {
        imports = [ inputs.sops-nix.homeManagerModules.sops ];
        sops = {
          defaultSopsFile = lib.mkDefault ./users/${host.primary-user.name}.sops.yaml;
          defaultSopsFormat = "yaml";
        };
      };
  };
}
