{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nix-darwin.url = "github:nix-darwin/nix-darwin";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core.url = "github:homebrew/homebrew-core";
    homebrew-core.flake = false;
    homebrew-cask.url = "github:homebrew/homebrew-cask";
    homebrew-cask.flake = false;
    homebrew-bundle.url = "github:homebrew/homebrew-bundle";
    homebrew-bundle.flake = false;
    homebrew-services.url = "github:homebrew/homebrew-services";
    homebrew-services.flake = false;
    homebrew-fvm.url = "github:leoafarias/fvm";
    homebrew-fvm.flake = false;
  };
}
