{
  description = "Dev inputs (not visible to flake consumers)";

  inputs = {
    root = {
      url = "path:../../../..";
      inputs = {
        authentik-nix.follows = "";
        catppuccin.follows = "";
        devenv.follows = "";
        disko.follows = "";
        home-manager.follows = "";
        homebrew-bundle.follows = "";
        homebrew-cask.follows = "";
        homebrew-core.follows = "";
        homebrew-fvm.follows = "";
        homebrew-services.follows = "";
        impermanence.follows = "";
        mcp-servers.follows = "";
        nh.follows = "";
        nix.follows = "";
        nix-darwin.follows = "";
        nix-homebrew.follows = "";
        nix-index-database.follows = "";
        nix-rosetta-builder.follows = "";
        nix-vscode-extensions.follows = "";
        nixos-generators.follows = "";
        nixos-hardware.follows = "";
        nur.follows = "";
        sops-nix.follows = "";
        topology.follows = "";
      };
    };

    nixpkgs.follows = "root/nixpkgs";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = _: { };
}
