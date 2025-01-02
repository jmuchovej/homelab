{ channels, ... }:
_final: _prev: {
  inherit (channels.nixpkgs-git) efitools;

  # https://github.com/NixOS/nixpkgs/pull/369293
  python3 = _prev.python3.override {
    packageOverrides = self: super: {
      inherit (channels.nixpkgs-git.python312Packages) dask-expr;
    };
  };
}
