{ inputs, lib, ... }:
{
  imports = [
    ./treefmt.nix
    ./checks.nix
    ./shells.nix
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
