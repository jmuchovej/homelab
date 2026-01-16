{ inputs }:
final: prev: {
  # Provides pkgs.unstable.* for using packages from nixpkgs-unstable
  unstable = import inputs.nixpkgs-unstable {
    system = prev.stdenv.hostPlatform.system;
    config = prev.config or { allowUnfree = true; };
  };
}
