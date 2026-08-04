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

    # Stays on the native `homeManager` class: the `hm` alias forwards through
    # den's `guardTree`, which reinterprets a function body as option
    # definitions — an `imports` list there becomes an undefined option.
    #
    # Keyed on `user`, not `host.primary-user`. den binds `_module.args.user` in
    # every scope — including a bare standalone home, where it synthesizes one
    # from the home's name — whereas `host` is absent there. Taking `host`
    # without a default made `class-module.nix` treat the block as unsatisfied
    # and drop it silently, so sops-nix was never imported into a portable home
    # and `nix.extraOptions` (which reads `sops.secrets."nix-access-tokens"`)
    # would fail on an undefined option.
    #
    # It is also the more accurate key on a host: a non-primary user such as
    # `lab` now gets its own `users/lab.sops.yaml` rather than the primary
    # user's file.
    homeManager =
      { user, lib, ... }:
      {
        imports = [ inputs.sops-nix.homeManagerModules.sops ];
        sops = {
          defaultSopsFile = lib.mkDefault ./users/${user.userName}.sops.yaml;
          defaultSopsFormat = "yaml";
        };
      };
  };
}
