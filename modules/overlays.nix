{
  inputs,
  lib,
  config,
  ...
}:
{
  flake.overlays = {
    rbn = import "${inputs.self}/packages/overlay.nix" { inherit inputs; };
  };

  den.default =
    let
      overlays = lib.attrValues config.flake.overlays;
    in
    {
      nixos.nixpkgs.overlays = overlays;
      darwin.nixpkgs.overlays = overlays;
      hm = { options, ... }: {
        nixpkgs.overlays = lib.mkIf (options.nixpkgs ? system) overlays;
      };
    };
}
