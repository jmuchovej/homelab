# Dev shell pkgs base: allowUnfree on the perSystem `pkgs` arg so the shell
# can include packages like `cachix` that nixpkgs marks as unfree-adjacent.
# Uses mkDefault so other modules can override the pkgs instance if needed.
{ inputs, lib, ... }:
{
  # Restrict flake-parts iteration to the systems actually relevant to this
  # homelab: x86_64-linux hosts and aarch64-darwin dev machines.
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = lib.mkDefault (
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    };
}
