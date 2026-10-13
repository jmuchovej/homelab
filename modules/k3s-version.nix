{ inputs, ... }:
{
  # The Kubernetes version the clusters actually run, exposed as a flake output
  # so `just bootstrap k8s update-schemas` can pin the vendored API schemas to
  # it without evaluating a named host — no single server is the authority on a
  # cluster-wide fact. Read with `nix eval --raw .#k3s-version`.
  #
  # Reading it off `inputs.nixpkgs` rather than a host's evaluated config is
  # what makes it cheap: no module system, and the result is eval-cached.
  # Nothing overlays or overrides `k3s`, so it matches what the hosts deploy;
  # if a host ever pins `services.k3s.package`, the schema-version assertion in
  # `bootstrap/kubernetes/checks.nix` compares against *that* host's config and
  # fails the build rather than letting the two drift silently.
  #
  # The system is pinned because k3s is Linux-only and this output has to
  # evaluate from a darwin workstation too. Every server is x86_64-linux.
  #
  # flake-parts' `flake` option is freeform, so this needs no option
  # declaration; `nix flake show` lists it as an unknown output, which is
  # cosmetic.
  flake.k3s-version = inputs.nixpkgs.legacyPackages.x86_64-linux.k3s.version;
}
