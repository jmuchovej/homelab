## Unstable overlay — nixpkgs input already follows nixpkgs-unstable,
## so pkgs.unstable is an alias for pkgs itself.
{ inputs }:
_final: prev: {
  unstable = import inputs.nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    config = prev.config;
  };
}
