{ __findFile, ... }:
{
  rbn.suite._.development = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          nix-index
          nix-init
          nix-melt
          nix-update
          nixpkgs-fmt
          nixpkgs-hammering
          nixpkgs-review
          nurl
        ];
      };
  };
}
