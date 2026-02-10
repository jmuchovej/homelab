{ inputs }:
_final: prev: {
  # Provides pkgs.unstable.* for using packages from nixpkgs-unstable
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    config = prev.config or { allowUnfree = true; };
  };
}
